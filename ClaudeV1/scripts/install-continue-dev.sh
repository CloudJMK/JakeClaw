#!/usr/bin/env bash
# =============================================================================
# install-continue-dev.sh — Install Continue.dev extension for code-server
#
# Installs the Continue extension and deploys the pre-configured config.yaml
# from the JakeClaw repo. Symlinks ~/.continue to /Jake-data/.continue for
# persistence across VM rebuilds.
#
# USER INPUT REQUIRED:
#   config/continue-config.yaml must have apiBase set to a live endpoint.
#   The default points to http://localhost:8000/v1 (jake-api / LiteLLM wrapper).
#   If using a remote model, update the apiBase and apiKey in .env.
#
# Idempotent: checks if extension already installed.
# =============================================================================
set -euo pipefail
[[ "${EUID}" -ne 0 ]] && { echo "Must run as root" >&2; exit 1; }

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKE_DATA="${JAKE_DATA:-/Jake-data}"
JAKECLAW_DIR="${JAKECLAW_DIR:-/JakeClaw}"

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [install-continue-dev] $*"; }

# ── Check if extension already installed ──────────────────────────────────
EXTENSIONS_DIR="${JAKE_HOME}/.local/share/code-server/extensions"
if ls "${EXTENSIONS_DIR}/continue*" 2>/dev/null | grep -q .; then
  log "Continue.dev already installed — skipping extension install"
else
  log "Installing Continue.dev extension..."

  # Try code-server extension install
  su - "${JAKE_USER}" -c "
    code-server --install-extension Continue.continue 2>/dev/null || \
    code --install-extension Continue.continue 2>/dev/null || \
    echo 'NOTE: Extension install via CLI skipped — install manually in code-server UI'
  " || log "Extension CLI install unavailable — will rely on manual install or marketplace"
fi

# ── Set up Continue config directory (persistent via /Jake-data) ──────────
PERSIST_DIR="${JAKE_DATA}/.continue"
LOCAL_DIR="${JAKE_HOME}/.continue"

mkdir -p "${PERSIST_DIR}"
chown -R "${JAKE_USER}:${JAKE_USER}" "${PERSIST_DIR}"

# Symlink ~/.continue → /Jake-data/.continue for persistence
su - "${JAKE_USER}" -c "
  if [[ -L '${LOCAL_DIR}' ]]; then
    echo 'Symlink already exists: ${LOCAL_DIR}'
  elif [[ -d '${LOCAL_DIR}' ]]; then
    # Migrate existing config into persistent volume
    cp -r '${LOCAL_DIR}/.' '${PERSIST_DIR}/' 2>/dev/null || true
    rm -rf '${LOCAL_DIR}'
    ln -sf '${PERSIST_DIR}' '${LOCAL_DIR}'
    echo 'Migrated and symlinked ${LOCAL_DIR} -> ${PERSIST_DIR}'
  else
    ln -sf '${PERSIST_DIR}' '${LOCAL_DIR}'
    echo 'Created symlink ${LOCAL_DIR} -> ${PERSIST_DIR}'
  fi
"

# ── Deploy JakeClaw Continue config ───────────────────────────────────────
CONFIG_SRC="${JAKECLAW_DIR}/config/continue-config.yaml"
CONFIG_DEST="${PERSIST_DIR}/config.yaml"

if [[ -f "${CONFIG_SRC}" ]]; then
  if [[ ! -f "${CONFIG_DEST}" ]]; then
    cp "${CONFIG_SRC}" "${CONFIG_DEST}"
    chown "${JAKE_USER}:${JAKE_USER}" "${CONFIG_DEST}"
    log "Deployed Continue config to ${CONFIG_DEST}"
  else
    log "Continue config already present — not overwriting (manual edits preserved)"
  fi
else
  log "WARNING: ${CONFIG_SRC} not found — Continue will use defaults"
fi

log "Continue.dev setup complete"
log "Open code-server → Continue sidebar (Ctrl+L) → 'Hello Jake, survey the codebase'"
