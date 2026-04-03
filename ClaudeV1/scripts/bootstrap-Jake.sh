#!/usr/bin/env bash
# =============================================================================
# bootstrap-Jake.sh — JakeClaw post-cloud-init orchestrator
#
# Runs as root on first boot (triggered by cloud-init runcmd).
# Calls each install-*.sh in order, then wires everything together.
#
# Logs: /var/log/jake-bootstrap.log
# Idempotent: safe to re-run; each sub-script checks before acting.
#
# USER INPUT REQUIRED:
#   Edit /etc/jake-deployment.conf (written by cloud-init) to set:
#     JAKE_USER, JAKE_HOME, JAKE_DATA, JAKECLAW_REPO
#   Or export those vars before calling this script.
# =============================================================================
set -euo pipefail

# ─── Require root ─────────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
  echo "[bootstrap] ERROR: must run as root (sudo bash bootstrap-Jake.sh)" >&2
  exit 1
fi

# ─── Load deployment config ───────────────────────────────────────────────────
CONF_FILE="/etc/jake-deployment.conf"
if [[ -f "$CONF_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONF_FILE"
fi

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKE_DATA="${JAKE_DATA:-/Jake-data}"
JAKECLAW_DIR="${JAKECLAW_DIR:-/JakeClaw}"

export JAKE_USER JAKE_HOME JAKE_DATA JAKECLAW_DIR

# ─── Logging helper ───────────────────────────────────────────────────────────
LOG_FILE="/var/log/jake-bootstrap.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [bootstrap] $*"; }

log "======================================================================"
log "JakeClaw bootstrap starting — JAKE_USER=$JAKE_USER"
log "======================================================================"

# ─── Helpers ──────────────────────────────────────────────────────────────────
run_script() {
  local script="$1"
  local path="${JAKECLAW_DIR}/scripts/${script}"
  if [[ -f "$path" ]]; then
    log "--- Running: $script ---"
    bash "$path"
    log "--- Done: $script ---"
  else
    log "WARNING: $path not found — skipping"
  fi
}

# ─── 1. Dev environment (git, node, rust, python, etc.) ──────────────────────
run_script "install-dev-env.sh"

# ─── 2. OpenClaw ──────────────────────────────────────────────────────────────
run_script "install-openclaw.sh"

# ─── 3. Claw-code (Rust harness) ──────────────────────────────────────────────
run_script "install-claw-code.sh"

# ─── 4. code-server (browser VS Code) ────────────────────────────────────────
run_script "install-code-server.sh"

# ─── 5. Continue.dev extension ───────────────────────────────────────────────
run_script "install-continue-dev.sh"

# ─── 6. OpenAI-compatible API wrapper (LiteLLM) ───────────────────────────────
run_script "setup-jake-api.sh"

# ─── 7. Expose Claw tools as OpenClaw skills ─────────────────────────────────
run_script "expose-claw-tools.sh"

# ─── 8. Self-improvement systemd timer ───────────────────────────────────────
run_script "setup-self-improvement.sh"

# ─── 9. Ensure /Jake-data ownership ──────────────────────────────────────────
log "Setting ownership of $JAKE_DATA"
mkdir -p "${JAKE_DATA}/logs" "${JAKE_DATA}/skills" "${JAKE_DATA}/.continue"
chown -R "${JAKE_USER}:${JAKE_USER}" "${JAKE_DATA}"

# ─── 10. Copy config files to Jake home ───────────────────────────────────────
log "Linking config files"
su - "${JAKE_USER}" -c "
  mkdir -p ~/.continue
  ln -sf ${JAKECLAW_DIR}/config/continue-config.yaml ~/.continue/config.yaml 2>/dev/null || true
"

# ─── Done ─────────────────────────────────────────────────────────────────────
log "======================================================================"
log "Bootstrap COMPLETE. Run 'bash ${JAKECLAW_DIR}/scripts/deploy-test.sh' to verify."
log "code-server: http://\$(hostname -I | awk '{print \$1}'):8080"
log "Jake API:    http://\$(hostname -I | awk '{print \$1}'):8000/v1/models"
log "======================================================================"
