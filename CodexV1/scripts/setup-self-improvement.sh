#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "setup-self-improvement.sh must run as root" >&2
  exit 1
fi

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force=1|--force) FORCE=1 ;;
  esac
done

if [[ "${FORCE}" -ne 1 ]]; then
  read -r -p "Install or update the self-improvement service and timer? [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || exit 1
fi

install -d -m 0755 /usr/local/bin
install -d -m 0755 /etc/systemd/system
install -d -o "${JAKE_USER:-jake}" -g "${JAKE_USER:-jake}" "${JAKE_DATA_DIR:-/Jake-data}/logs"

cat > /usr/local/bin/jake-self-improve.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="/tmp/jake-self-improve.lock"
LOG_DIR="${JAKE_DATA_DIR:-/Jake-data}/logs"
LOG_FILE="${LOG_DIR}/jake-self-improve.log"
REPO_DIR="${JAKE_REPO_DIR:-/opt/JakeClaw}"
REPO_REMOTE="${JAKE_REPO_REMOTE:-origin}"
REPO_BRANCH="${JAKE_REPO_BRANCH:-main}"
CLAW_BIN="/usr/local/bin/claw"
BACKUP_BIN="/usr/local/bin/claw.previous"

mkdir -p "${LOG_DIR}"
exec 9>"${LOCK_FILE}"
flock -n 9 || {
  echo "Self-improvement run already in progress" >> "${LOG_FILE}"
  exit 0
}

{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Starting self-improvement run"

  if [[ ! -d "${REPO_DIR}/.git" ]]; then
    echo "Repo directory not found: ${REPO_DIR}"
    exit 1
  fi

  if [[ -n "$(git -C "${REPO_DIR}" status --porcelain)" ]]; then
    echo "Local changes detected in ${REPO_DIR}; skipping git pull."
    exit 0
  fi

  git -C "${REPO_DIR}" pull --ff-only "${REPO_REMOTE}" "${REPO_BRANCH}"

  if [[ -x "${CLAW_BIN}" ]]; then
    cp -f "${CLAW_BIN}" "${BACKUP_BIN}"
  fi

  if [[ -x "${REPO_DIR}/scripts/install-claw-code.sh" ]]; then
    if ! /bin/bash "${REPO_DIR}/scripts/install-claw-code.sh" --force=1; then
      echo "Rebuild failed; restoring previous claw binary if present."
      if [[ -x "${BACKUP_BIN}" ]]; then
        cp -f "${BACKUP_BIN}" "${CLAW_BIN}"
      fi
      exit 1
    fi
  fi

  if [[ -x "${REPO_DIR}/scripts/expose-claw-tools.sh" ]]; then
    /bin/bash "${REPO_DIR}/scripts/expose-claw-tools.sh" --force=1 --reload
  fi

  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Self-improvement run completed"
} >> "${LOG_FILE}" 2>&1
EOF

chmod 0755 /usr/local/bin/jake-self-improve.sh

cat > /etc/systemd/system/jake-self-improve.service <<EOF
[Unit]
Description=Jake self-improvement worker
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${JAKE_USER:-jake}
EnvironmentFile=-${JAKE_REPO_DIR:-/opt/JakeClaw}/config/.env
ExecStart=/usr/local/bin/jake-self-improve.sh
EOF

cat > /etc/systemd/system/jake-self-improve.timer <<'EOF'
[Unit]
Description=Run Jake self-improvement every hour

[Timer]
OnBootSec=10m
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now jake-self-improve.timer
