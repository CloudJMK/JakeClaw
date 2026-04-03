#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "install-claw-code.sh must run as root" >&2
  exit 1
fi

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force=1|--force) FORCE=1 ;;
  esac
done

if [[ "${FORCE}" -ne 1 ]]; then
  read -r -p "Install or update Claw-code? [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || exit 1
fi

CLAW_CODE_REPO_URL="${CLAW_CODE_REPO_URL:-}"
CLAW_CODE_REF="${CLAW_CODE_REF:-main}"
CLAW_DIR="/opt/claw-code"

if [[ -z "${CLAW_CODE_REPO_URL}" || "${CLAW_CODE_REPO_URL}" == *"your-org"* ]]; then
  echo "Claw-code repo URL is not configured. Skipping install."
  echo "# REQUIRED INPUT: set CLAW_CODE_REPO_URL in config/.env" >&2
  exit 0
fi

apt-get update -y
apt-get install -y git pkg-config libssl-dev build-essential

if [[ -d "${CLAW_DIR}/.git" ]]; then
  git -C "${CLAW_DIR}" fetch --all --tags
else
  git clone "${CLAW_CODE_REPO_URL}" "${CLAW_DIR}"
fi

git -C "${CLAW_DIR}" checkout "${CLAW_CODE_REF}"

if [[ -f "${CLAW_DIR}/Cargo.toml" ]]; then
  su - "${JAKE_USER:-jake}" -c "cd '${CLAW_DIR}' && \$HOME/.cargo/bin/cargo build --release"
  install -m 0755 "${CLAW_DIR}/target/release/claw" /usr/local/bin/claw
fi

if [[ -f "${CLAW_DIR}/pyproject.toml" || -f "${CLAW_DIR}/requirements.txt" ]]; then
  python3 -m pip install -e "${CLAW_DIR}" || true
fi

cat > /etc/systemd/system/claw-code.service <<EOF
[Unit]
Description=Claw-code API service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${JAKE_USER:-jake}
WorkingDirectory=${CLAW_DIR}
EnvironmentFile=-${JAKE_REPO_DIR:-/opt/JakeClaw}/config/.env
ExecStart=/usr/local/bin/claw serve --host 127.0.0.1 --port 8081
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now claw-code.service || true
