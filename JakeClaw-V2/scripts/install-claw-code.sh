#!/usr/bin/env bash
# install-claw-code.sh — Build and install claw-code from source
#
# Clones the claw-code repo, builds with cargo, installs the binary to
# /usr/local/bin/claw, and registers a systemd service on port 8081.
# Uses a source hash to skip rebuilds when nothing has changed.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: Must run as root" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi  # shellcheck source=/dev/null

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
CLAW_CODE_REPO_URL="${CLAW_CODE_REPO_URL:-https://github.com/anthropics/claude-code}"
CLAW_CODE_REF="${CLAW_CODE_REF:-main}"
CLAW_SERVER_PORT="${CLAW_SERVER_PORT:-8081}"

CLAW_SRC="/home/${JAKE_USER}/claw-code-src"
CLAW_BIN="/usr/local/bin/claw"
HASH_FILE="/var/lib/jake/claw-installed-hash"
STATE_DIR="/var/lib/jake"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] install-claw-code: $*"; }
log "Starting"

# Ensure PATH includes cargo
export PATH="${JAKE_HOME}/.cargo/bin:/usr/local/bin:${PATH}"

mkdir -p "$STATE_DIR"

# ---------------------------------------------------------------------------
# Clone or update source
# ---------------------------------------------------------------------------
if [[ ! -d "$CLAW_SRC/.git" ]]; then
  log "Cloning claw-code from ${CLAW_CODE_REPO_URL}"
  sudo -u "$JAKE_USER" git clone --depth=1 --branch "$CLAW_CODE_REF" \
    "$CLAW_CODE_REPO_URL" "$CLAW_SRC"
else
  log "Updating existing claw-code checkout"
  sudo -u "$JAKE_USER" git -C "$CLAW_SRC" fetch --quiet origin
  sudo -u "$JAKE_USER" git -C "$CLAW_SRC" reset --hard "origin/${CLAW_CODE_REF}"
fi

# ---------------------------------------------------------------------------
# Check if rebuild is needed (hash-based, idempotent)
# ---------------------------------------------------------------------------
CURRENT_HASH=$(find "$CLAW_SRC/src" -name "*.rs" -exec sha256sum {} \; 2>/dev/null \
  | sort | sha256sum | cut -d' ' -f1 || echo "unknown")
INSTALLED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "none")

if [[ "$CURRENT_HASH" == "$INSTALLED_HASH" && -x "$CLAW_BIN" ]]; then
  log "Source unchanged (hash=${CURRENT_HASH:0:12}…) — skipping rebuild"
else
  log "Building claw-code (hash changed or first install)"

  # Back up existing binary for rollback
  if [[ -x "$CLAW_BIN" ]]; then
    cp "$CLAW_BIN" "${CLAW_BIN}.bak"
    log "Backed up existing binary to ${CLAW_BIN}.bak"
  fi

  # Build (as jake user so cargo cache is in jake's home)
  if sudo -u "$JAKE_USER" bash -c \
      "cd '${CLAW_SRC}' && PATH='${JAKE_HOME}/.cargo/bin:\$PATH' cargo build --release 2>&1"; then
    cp "${CLAW_SRC}/target/release/claw" "$CLAW_BIN"
    chmod +x "$CLAW_BIN"
    echo "$CURRENT_HASH" > "$HASH_FILE"
    log "Build succeeded — installed to ${CLAW_BIN}"
  else
    log "ERROR: Build failed"
    if [[ -f "${CLAW_BIN}.bak" ]]; then
      log "Rolling back to previous binary"
      cp "${CLAW_BIN}.bak" "$CLAW_BIN"
    fi
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Install placeholder if real binary is still missing
# ---------------------------------------------------------------------------
if [[ ! -x "$CLAW_BIN" ]]; then
  log "WARNING: No claw binary — installing stub"
  cat > "$CLAW_BIN" << 'EOF'
#!/usr/bin/env bash
echo '{"tools":[],"version":"stub"}' ; exit 0
EOF
  chmod +x "$CLAW_BIN"
fi

# ---------------------------------------------------------------------------
# Systemd service for claw-code API server
# ---------------------------------------------------------------------------
cat > /etc/systemd/system/claw-code.service << EOF
[Unit]
Description=claw-code tool API server
After=network.target
Wants=network.target

[Service]
User=${JAKE_USER}
Environment="HOME=${JAKE_HOME}"
Environment="PATH=${JAKE_HOME}/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=${CLAW_BIN} serve --port ${CLAW_SERVER_PORT}
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

if [[ -x "$CLAW_BIN" ]] && "$CLAW_BIN" --version &>/dev/null; then
  systemctl enable --now claw-code.service
  log "claw-code.service enabled and started"
else
  log "Stub binary detected — claw-code.service NOT started (enable manually after real build)"
fi

log "Done"
