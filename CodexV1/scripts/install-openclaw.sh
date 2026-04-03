#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "install-openclaw.sh must run as root" >&2
  exit 1
fi

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force=1|--force) FORCE=1 ;;
  esac
done

if [[ "${FORCE}" -ne 1 ]]; then
  read -r -p "Install or update OpenClaw? [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || exit 1
fi

OPENCLAW_REPO_URL="${OPENCLAW_REPO_URL:-}"
OPENCLAW_REF="${OPENCLAW_REF:-main}"
OPENCLAW_DIR="/opt/openclaw"

if [[ -z "${OPENCLAW_REPO_URL}" || "${OPENCLAW_REPO_URL}" == *"your-org"* ]]; then
  echo "OpenClaw repo URL is not configured. Skipping install."
  echo "# REQUIRED INPUT: set OPENCLAW_REPO_URL in config/.env" >&2
  exit 0
fi

apt-get update -y
apt-get install -y git python3 python3-pip python3-venv

if [[ -d "${OPENCLAW_DIR}/.git" ]]; then
  git -C "${OPENCLAW_DIR}" fetch --all --tags
else
  git clone "${OPENCLAW_REPO_URL}" "${OPENCLAW_DIR}"
fi

git -C "${OPENCLAW_DIR}" checkout "${OPENCLAW_REF}"

if [[ -f "${OPENCLAW_DIR}/package.json" ]]; then
  if command -v npm >/dev/null 2>&1; then
    npm --prefix "${OPENCLAW_DIR}" install
    npm --prefix "${OPENCLAW_DIR}" run build || true
  fi
fi

if [[ -f "${OPENCLAW_DIR}/requirements.txt" ]]; then
  python3 -m pip install -r "${OPENCLAW_DIR}/requirements.txt"
fi

cat > /usr/local/bin/openclaw <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -x /opt/openclaw/bin/openclaw ]]; then
  exec /opt/openclaw/bin/openclaw "$@"
fi

if [[ -f /opt/openclaw/package.json ]] && command -v npm >/dev/null 2>&1; then
  exec npm --prefix /opt/openclaw run start -- "$@"
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 -m openclaw "$@"
fi

echo "OpenClaw launcher could not determine how to start the upstream project." >&2
exit 1
EOF
chmod +x /usr/local/bin/openclaw

install -d -m 0755 /etc/openclaw
install -m 0644 "${JAKE_REPO_DIR:-/opt/JakeClaw}/config/openclaw-config.json" /etc/openclaw/config.json

cat > /etc/systemd/system/openclaw.service <<EOF
[Unit]
Description=OpenClaw service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${JAKE_USER:-jake}
WorkingDirectory=${OPENCLAW_DIR}
Environment=OPENCLAW_CONFIG=/etc/openclaw/config.json
EnvironmentFile=-${JAKE_REPO_DIR:-/opt/JakeClaw}/config/.env
ExecStart=/usr/local/bin/openclaw serve --config /etc/openclaw/config.json
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now openclaw.service || true
