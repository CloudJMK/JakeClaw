#!/usr/bin/env bash
# install-code-server.sh — Install code-server (browser-based VS Code)
#
# Installs via the official install script, writes config, and enables
# the systemd service so it starts on boot.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: Must run as root" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi  # shellcheck source=/dev/null

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
CODE_SERVER_BIND_ADDR="${CODE_SERVER_BIND_ADDR:-0.0.0.0:8080}"
CODE_SERVER_AUTH="${CODE_SERVER_AUTH:-password}"
CODE_SERVER_PASSWORD="${CODE_SERVER_PASSWORD:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] install-code-server: $*"; }
log "Starting"

# ---------------------------------------------------------------------------
# Install (idempotent)
# ---------------------------------------------------------------------------
if command -v code-server &>/dev/null; then
  log "code-server already installed: $(code-server --version 2>/dev/null | head -1)"
else
  log "Downloading and installing code-server"
  curl -fsSL https://code-server.dev/install.sh | sh
fi

# ---------------------------------------------------------------------------
# Write config for jake user
# ---------------------------------------------------------------------------
CONFIG_DIR="${JAKE_HOME}/.config/code-server"
mkdir -p "$CONFIG_DIR"

CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# Only write if not already configured (idempotent)
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" << EOF
bind-addr: ${CODE_SERVER_BIND_ADDR}
auth: ${CODE_SERVER_AUTH}
password: ${CODE_SERVER_PASSWORD}
cert: false
EOF
  log "Config written to ${CONFIG_FILE}"
else
  log "Config already exists at ${CONFIG_FILE} — not overwriting"
fi

chown -R "${JAKE_USER}:${JAKE_USER}" "$CONFIG_DIR"

if [[ -z "$CODE_SERVER_PASSWORD" ]]; then
  log "WARNING: CODE_SERVER_PASSWORD is not set — code-server will require a random password"
  log "         Set CODE_SERVER_PASSWORD in ../.env and re-run to apply"
fi

# ---------------------------------------------------------------------------
# Enable systemd service
# ---------------------------------------------------------------------------
systemctl enable --now "code-server@${JAKE_USER}"
log "code-server@${JAKE_USER} enabled and started"
log "Access at http://<VM-IP>:${CODE_SERVER_BIND_ADDR##*:}"

log "Done"
