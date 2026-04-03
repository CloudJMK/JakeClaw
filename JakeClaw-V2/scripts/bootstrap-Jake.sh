#!/usr/bin/env bash
# bootstrap-Jake.sh — Main entry point for Jake VM setup
#
# Called by cloud-init runcmd on first boot. Runs all install/setup scripts
# in order, logging everything to /var/log/jake-bootstrap.log.
#
# Usage: sudo bash bootstrap-Jake.sh [--force]

set -euo pipefail

FORCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Locate the repo and load environment
# ---------------------------------------------------------------------------
# REPO_DIR is set in /etc/jake-deployment.conf by cloud-init write_files.
CONF_FILE="/etc/jake-deployment.conf"
if [[ -f "$CONF_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONF_FILE"
else
  # Fallback: derive REPO_DIR from script location
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

ENV_FILE="${REPO_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKE_DATA_DIR="${JAKE_DATA_DIR:-/Jake-data}"
SCRIPTS_DIR="${REPO_DIR}/scripts"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
LOG_FILE="/var/log/jake-bootstrap.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $*"; exit 1; }

log "======================================================"
log " JakeClaw-V2 Bootstrap  (force=${FORCE})"
log " Repo: ${REPO_DIR}"
log " Jake user: ${JAKE_USER}"
log "======================================================"

[[ $EUID -eq 0 ]] || die "Must be run as root (e.g. sudo bash bootstrap-Jake.sh)"

# ---------------------------------------------------------------------------
# Ensure /Jake-data directory structure exists
# ---------------------------------------------------------------------------
for d in "${JAKE_DATA_DIR}" \
          "${JAKE_DATA_DIR}/logs" \
          "${JAKE_DATA_DIR}/logs/openclaw" \
          "${JAKE_DATA_DIR}/skills" \
          "${JAKE_DATA_DIR}/workspace" \
          "${JAKE_DATA_DIR}/.continue"; do
  mkdir -p "$d"
done
chown -R "${JAKE_USER}:${JAKE_USER}" "${JAKE_DATA_DIR}"

# ---------------------------------------------------------------------------
# Helper: run a sub-script with standard logging
# ---------------------------------------------------------------------------
run_step() {
  local script="$1"
  local path="${SCRIPTS_DIR}/${script}"

  if [[ ! -f "$path" ]]; then
    die "Script not found: ${path}"
  fi

  log "------ Starting: ${script} ------"
  FORCE_FLAG=""
  if [[ "$FORCE" == "true" ]]; then FORCE_FLAG="--force"; fi

  bash "$path" $FORCE_FLAG
  log "------ Completed: ${script} ------"
}

# ---------------------------------------------------------------------------
# Run each step in order
# ---------------------------------------------------------------------------
run_step install-dev-env.sh
run_step install-openclaw.sh
run_step install-claw-code.sh
run_step install-code-server.sh
run_step install-continue-dev.sh
run_step setup-jake-api.sh
run_step setup-self-improvement.sh
run_step expose-claw-tools.sh

# ---------------------------------------------------------------------------
# Symlink ~/.continue → /Jake-data/.continue for persistence
# ---------------------------------------------------------------------------
CONTINUE_SRC="${JAKE_DATA_DIR}/.continue"
CONTINUE_LINK="${JAKE_HOME}/.continue"

if [[ -d "$CONTINUE_LINK" && ! -L "$CONTINUE_LINK" ]]; then
  log "Migrating existing ~/.continue to ${CONTINUE_SRC}"
  cp -r "$CONTINUE_LINK" "$CONTINUE_SRC"
  rm -rf "$CONTINUE_LINK"
fi
if [[ ! -L "$CONTINUE_LINK" ]]; then
  ln -sf "$CONTINUE_SRC" "$CONTINUE_LINK"
  chown -h "${JAKE_USER}:${JAKE_USER}" "$CONTINUE_LINK"
fi

# Copy Continue config if not already present on the persistent volume
CONTINUE_CONFIG="${CONTINUE_SRC}/config.yaml"
if [[ ! -f "$CONTINUE_CONFIG" ]]; then
  cp "${REPO_DIR}/config/continue-config.yaml" "$CONTINUE_CONFIG"
  chown "${JAKE_USER}:${JAKE_USER}" "$CONTINUE_CONFIG"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "======================================================"
log " Bootstrap complete!"
log ""
log " Access Jake at:"
log "   code-server IDE : http://<VM-IP>:8080"
log "   Jake API        : http://<VM-IP>:8000"
log "   claw-code API   : http://<VM-IP>:8081"
log ""
log " Run deploy-test.sh to verify all services."
log "======================================================"
