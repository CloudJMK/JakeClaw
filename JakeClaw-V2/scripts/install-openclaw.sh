#!/usr/bin/env bash
# install-openclaw.sh — Install and configure the OpenClaw / claude-code CLI
#
# Installs @anthropic-ai/claude-code globally via npm, writes the API key to
# jake's environment, and copies openclaw-config.json to ~/.claude/settings.json.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: Must run as root" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi  # shellcheck source=/dev/null

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] install-openclaw: $*"; }
log "Starting"

# ---------------------------------------------------------------------------
# Install @anthropic-ai/claude-code (idempotent)
# ---------------------------------------------------------------------------
if command -v claude &>/dev/null; then
  log "claude-code already installed: $(claude --version 2>/dev/null || echo 'version unknown')"
else
  log "Installing @anthropic-ai/claude-code via npm"
  npm install -g @anthropic-ai/claude-code --quiet
fi

# ---------------------------------------------------------------------------
# Persist API key in jake's shell environment
# ---------------------------------------------------------------------------
BASHRC="${JAKE_HOME}/.bashrc"
if [[ -n "$ANTHROPIC_API_KEY" ]]; then
  if ! grep -q "ANTHROPIC_API_KEY" "$BASHRC" 2>/dev/null; then
    echo "export ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}" >> "$BASHRC"
    chown "${JAKE_USER}:${JAKE_USER}" "$BASHRC"
    log "API key written to ${BASHRC}"
  else
    log "API key already present in ${BASHRC}"
  fi
else
  log "WARNING: ANTHROPIC_API_KEY not set — jake will need it before using claude-code"
fi

# ---------------------------------------------------------------------------
# Install openclaw-config.json as ~/.claude/settings.json
# ---------------------------------------------------------------------------
CLAUDE_SETTINGS_DIR="${JAKE_HOME}/.claude"
mkdir -p "$CLAUDE_SETTINGS_DIR"
chown "${JAKE_USER}:${JAKE_USER}" "$CLAUDE_SETTINGS_DIR"

CONFIG_SRC="${REPO_DIR}/config/openclaw-config.json"
CONFIG_DST="${CLAUDE_SETTINGS_DIR}/settings.json"

if [[ -f "$CONFIG_SRC" ]]; then
  cp "$CONFIG_SRC" "$CONFIG_DST"
  chown "${JAKE_USER}:${JAKE_USER}" "$CONFIG_DST"
  log "Installed openclaw-config.json → ${CONFIG_DST}"
else
  log "WARNING: ${CONFIG_SRC} not found — skipping settings install"
fi

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
if command -v claude &>/dev/null; then
  log "Verification OK: $(claude --version 2>/dev/null || echo 'installed')"
else
  log "ERROR: claude command not found after install"
  exit 1
fi

log "Done"
