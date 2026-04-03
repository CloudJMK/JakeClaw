#!/usr/bin/env bash
# setup-self-improvement.sh — Install Jake's scheduled self-improvement system
#
# Creates a worker script + systemd service + timer that runs periodically to:
#   1. Pull the latest JakeClaw repo changes
#   2. Rebuild claw-code if source changed (with rollback on failure)
#   3. Regenerate dynamic skill files from claw manifest
#   4. Restart affected services

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: Must run as root" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi  # shellcheck source=/dev/null

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKE_DATA_DIR="${JAKE_DATA_DIR:-/Jake-data}"
JAKE_REPO_DIR="${JAKE_REPO_DIR:-/JakeClaw}"
JAKE_IMPROVE_SCHEDULE="${JAKE_IMPROVE_SCHEDULE:-02,08,14,20}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] setup-self-improvement: $*"; }
log "Starting (schedule hours: ${JAKE_IMPROVE_SCHEDULE})"

STATE_DIR="/var/lib/jake"
mkdir -p "$STATE_DIR"
mkdir -p "${JAKE_DATA_DIR}/logs"

# ---------------------------------------------------------------------------
# Worker script
# ---------------------------------------------------------------------------
cat > /usr/local/bin/jake-self-improve.sh << 'WORKER_EOF'
#!/usr/bin/env bash
# jake-self-improve.sh — Self-improvement worker (run by systemd timer)
set -euo pipefail

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKE_DATA_DIR="${JAKE_DATA_DIR:-/Jake-data}"
JAKE_REPO_DIR="${JAKE_REPO_DIR:-/JakeClaw}"
CLAW_BIN="/usr/local/bin/claw"
LOG_FILE="${JAKE_DATA_DIR}/logs/self-improvement.log"
LOCK_FILE="/run/jake-self-improve.lock"
HASH_FILE="/var/lib/jake/claw-installed-hash"

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# Prevent concurrent runs
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log "Another self-improvement run is already in progress — skipping"
  exit 0
fi

log "========================================"
log " Jake self-improvement cycle starting"
log "========================================"

# --- Step 1: Pull latest repo changes ---
log "Step 1: git pull (fast-forward only)"
if sudo -u "$JAKE_USER" git -C "$JAKE_REPO_DIR" pull --ff-only --quiet 2>&1 | tee -a "$LOG_FILE"; then
  log "Repo up to date"
else
  log "WARNING: git pull failed — continuing without update"
fi

# --- Step 2: Rebuild claw-code if source changed ---
log "Step 2: Check claw-code source hash"
CLAW_SRC="${JAKE_HOME}/claw-code-src"
if [[ -d "${CLAW_SRC}/src" ]]; then
  CURRENT_HASH=$(find "${CLAW_SRC}/src" -name "*.rs" -exec sha256sum {} \; 2>/dev/null \
    | sort | sha256sum | cut -d' ' -f1 || echo "unknown")
  INSTALLED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "none")

  if [[ "$CURRENT_HASH" != "$INSTALLED_HASH" ]]; then
    log "Source changed — rebuilding claw-code"

    if [[ -x "$CLAW_BIN" ]]; then
      cp "$CLAW_BIN" "${CLAW_BIN}.bak"
      log "Backed up ${CLAW_BIN} → ${CLAW_BIN}.bak"
    fi

    if sudo -u "$JAKE_USER" bash -c \
        "cd '${CLAW_SRC}' && PATH='${JAKE_HOME}/.cargo/bin:\$PATH' cargo build --release 2>&1" \
        | tee -a "$LOG_FILE"; then
      cp "${CLAW_SRC}/target/release/claw" "$CLAW_BIN"
      chmod +x "$CLAW_BIN"
      echo "$CURRENT_HASH" > "$HASH_FILE"
      log "Rebuild succeeded"
    else
      log "ERROR: Rebuild failed — rolling back"
      if [[ -f "${CLAW_BIN}.bak" ]]; then
        cp "${CLAW_BIN}.bak" "$CLAW_BIN"
        log "Rollback complete"
      fi
    fi
  else
    log "Source unchanged — skipping rebuild"
  fi
else
  log "claw-code source not found at ${CLAW_SRC} — skipping rebuild"
fi

# --- Step 3: Regenerate dynamic skills ---
log "Step 3: Regenerating dynamic skills"
EXPOSE_SCRIPT="${JAKE_REPO_DIR}/scripts/expose-claw-tools.sh"
if [[ -f "$EXPOSE_SCRIPT" ]]; then
  bash "$EXPOSE_SCRIPT" 2>&1 | tee -a "$LOG_FILE" || log "WARNING: expose-claw-tools.sh failed"
else
  log "WARNING: ${EXPOSE_SCRIPT} not found — skipping skill regeneration"
fi

# --- Step 4: Restart services ---
log "Step 4: Restarting services"
for svc in claw-code.service jake-api.service; do
  if systemctl is-active --quiet "$svc"; then
    systemctl restart "$svc"
    log "Restarted ${svc}"
  else
    log "Skipped restart of ${svc} (not running)"
  fi
done

log "Self-improvement cycle complete"
log "========================================"
WORKER_EOF

chmod +x /usr/local/bin/jake-self-improve.sh

# ---------------------------------------------------------------------------
# Systemd service
# ---------------------------------------------------------------------------
cat > /etc/systemd/system/jake-self-improve.service << EOF
[Unit]
Description=Jake self-improvement worker
After=network.target

[Service]
Type=oneshot
User=root
Environment="JAKE_USER=${JAKE_USER}"
Environment="JAKE_HOME=${JAKE_HOME}"
Environment="JAKE_DATA_DIR=${JAKE_DATA_DIR}"
Environment="JAKE_REPO_DIR=${JAKE_REPO_DIR}"
ExecStart=/usr/local/bin/jake-self-improve.sh
StandardOutput=journal
StandardError=journal
EOF

# ---------------------------------------------------------------------------
# Systemd timer
# ---------------------------------------------------------------------------
cat > /etc/systemd/system/jake-self-improve.timer << EOF
[Unit]
Description=Jake self-improvement timer
Requires=jake-self-improve.service

[Timer]
OnCalendar=*-*-* ${JAKE_IMPROVE_SCHEDULE}:00:00
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now jake-self-improve.timer
log "jake-self-improve.timer enabled (runs at hours: ${JAKE_IMPROVE_SCHEDULE} UTC)"
log "Manual trigger: systemctl start jake-self-improve.service"

log "Done"
