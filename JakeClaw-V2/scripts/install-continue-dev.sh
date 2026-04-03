#!/usr/bin/env bash
# install-continue-dev.sh — Install the Continue.dev extension into code-server
#
# Installs the Continue extension, creates the persistent config directory
# on /Jake-data, and wires up the symlink so config survives VM rebuilds.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: Must run as root" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi  # shellcheck source=/dev/null

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKE_DATA_DIR="${JAKE_DATA_DIR:-/Jake-data}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] install-continue-dev: $*"; }
log "Starting"

CONTINUE_PERSISTENT="${JAKE_DATA_DIR}/.continue"
CONTINUE_LINK="${JAKE_HOME}/.continue"
EXTENSIONS_DIR="${JAKE_HOME}/.local/share/code-server/extensions"

# ---------------------------------------------------------------------------
# Install Continue extension
# ---------------------------------------------------------------------------
CONTINUE_INSTALLED=false
if ls "$EXTENSIONS_DIR"/continue.continue-* &>/dev/null 2>&1; then
  log "Continue extension already installed"
  CONTINUE_INSTALLED=true
fi

if [[ "$CONTINUE_INSTALLED" != "true" ]]; then
  log "Installing Continue extension"

  INSTALL_OK=false

  # Try code-server CLI first
  if command -v code-server &>/dev/null; then
    if sudo -u "$JAKE_USER" code-server --install-extension continue.continue 2>/dev/null; then
      INSTALL_OK=true
      log "Installed via code-server CLI"
    fi
  fi

  # Fallback: try VS Code CLI
  if [[ "$INSTALL_OK" != "true" ]] && command -v code &>/dev/null; then
    if sudo -u "$JAKE_USER" code --install-extension continue.continue 2>/dev/null; then
      INSTALL_OK=true
      log "Installed via code CLI"
    fi
  fi

  if [[ "$INSTALL_OK" != "true" ]]; then
    log "WARNING: Could not install Continue extension automatically"
    log "         Install manually: code-server --install-extension continue.continue"
  fi
fi

# ---------------------------------------------------------------------------
# Persistent config directory on /Jake-data (survives VM rebuild)
# ---------------------------------------------------------------------------
mkdir -p "$CONTINUE_PERSISTENT"
chown -R "${JAKE_USER}:${JAKE_USER}" "$CONTINUE_PERSISTENT"

# Migrate existing ~/.continue into persistent storage
if [[ -d "$CONTINUE_LINK" && ! -L "$CONTINUE_LINK" ]]; then
  log "Migrating ${CONTINUE_LINK} → ${CONTINUE_PERSISTENT}"
  cp -r "${CONTINUE_LINK}/." "$CONTINUE_PERSISTENT/"
  rm -rf "$CONTINUE_LINK"
fi

# Create symlink
if [[ ! -L "$CONTINUE_LINK" ]]; then
  ln -sf "$CONTINUE_PERSISTENT" "$CONTINUE_LINK"
  chown -h "${JAKE_USER}:${JAKE_USER}" "$CONTINUE_LINK"
  log "Symlinked ${CONTINUE_LINK} → ${CONTINUE_PERSISTENT}"
else
  log "Symlink already in place: ${CONTINUE_LINK}"
fi

# ---------------------------------------------------------------------------
# Install config (never overwrite existing)
# ---------------------------------------------------------------------------
CONFIG_DST="${CONTINUE_PERSISTENT}/config.yaml"
CONFIG_SRC="${REPO_DIR}/config/continue-config.yaml"

if [[ ! -f "$CONFIG_DST" && -f "$CONFIG_SRC" ]]; then
  cp "$CONFIG_SRC" "$CONFIG_DST"
  chown "${JAKE_USER}:${JAKE_USER}" "$CONFIG_DST"
  log "Installed continue-config.yaml to ${CONFIG_DST}"
else
  log "Config already present at ${CONFIG_DST} — not overwriting"
fi

log "Done"
