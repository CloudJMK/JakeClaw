#!/usr/bin/env bash
# =============================================================================
# install-code-server.sh — Install code-server (browser-accessible VS Code)
#
# Installs code-server and sets it up as a systemd service for the jake user.
# Access: http://<VM_IP>:8080
#
# USER INPUT REQUIRED:
#   CODE_SERVER_PASSWORD — set in config/.env or leave blank for no-auth
#     (no-auth is acceptable on a private home network per the threat model)
#
# Idempotent: skips if code-server already installed.
# =============================================================================
set -euo pipefail
[[ "${EUID}" -ne 0 ]] && { echo "Must run as root" >&2; exit 1; }

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKECLAW_DIR="${JAKECLAW_DIR:-/JakeClaw}"

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [install-code-server] $*"; }

# ── Load .env ──────────────────────────────────────────────────────────────
ENV_FILE="${JAKECLAW_DIR}/config/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"  # shellcheck source=/dev/null

CODE_SERVER_PASSWORD="${CODE_SERVER_PASSWORD:-}"   # optional

# ── Check existing install ─────────────────────────────────────────────────
if command -v code-server >/dev/null 2>&1; then
  log "code-server already installed: $(code-server --version) — skipping"
  exit 0
fi

log "Installing code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

# ── Configure code-server ──────────────────────────────────────────────────
mkdir -p "${JAKE_HOME}/.config/code-server"
CONFIG_FILE="${JAKE_HOME}/.config/code-server/config.yaml"

if [[ -n "${CODE_SERVER_PASSWORD}" ]]; then
  AUTH_MODE="password"
  PASSWORD_LINE="password: ${CODE_SERVER_PASSWORD}"
else
  # No auth — acceptable on private home network (see threat model)
  AUTH_MODE="none"
  PASSWORD_LINE="# no password (auth: none)"
fi

cat > "${CONFIG_FILE}" << EOF
# code-server configuration for JakeClaw
# USER INPUT OPTIONAL: set CODE_SERVER_PASSWORD in config/.env for password auth
bind-addr: 0.0.0.0:8080
auth: ${AUTH_MODE}
${PASSWORD_LINE}
cert: false
# Open JakeClaw repo as default workspace
#user-data-dir: ${JAKE_HOME}/.local/share/code-server
EOF

chown -R "${JAKE_USER}:${JAKE_USER}" "${JAKE_HOME}/.config"

# ── Systemd service ────────────────────────────────────────────────────────
# Install the user systemd service (code-server ships this template)
systemctl enable --now "code-server@${JAKE_USER}" 2>/dev/null || {
  # Fallback: create service manually
  cat > /etc/systemd/system/code-server.service << SVCEOF
[Unit]
Description=code-server (JakeClaw IDE)
After=network.target

[Service]
Type=simple
User=${JAKE_USER}
ExecStart=/usr/bin/code-server --config ${JAKE_HOME}/.config/code-server/config.yaml /JakeClaw
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF
  systemctl daemon-reload
  systemctl enable --now code-server.service
}

log "code-server installed and running on port 8080"
log "Access: http://\$(hostname -I | awk '{print \$1}'):8080"
