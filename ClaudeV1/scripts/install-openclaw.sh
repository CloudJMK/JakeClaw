#!/usr/bin/env bash
# =============================================================================
# install-openclaw.sh — Install OpenClaw (Claude Code CLI / agent gateway)
#
# USER INPUT REQUIRED:
#   OpenClaw is the Claude Code CLI harness. Installation requires:
#     1. A valid Anthropic API key (set ANTHROPIC_API_KEY in /etc/jake-deployment.conf
#        or config/.env before running this script)
#     2. Network access to install via npm (npm install -g @anthropic-ai/claude-code)
#        or direct binary if pinning a version.
#
#   ANTHROPIC_API_KEY="{{ANTHROPIC_API_KEY}}"   ← fill in config/.env
#
# Idempotent: checks for existing install.
# =============================================================================
set -euo pipefail
[[ "${EUID}" -ne 0 ]] && { echo "Must run as root" >&2; exit 1; }

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKECLAW_DIR="${JAKECLAW_DIR:-/JakeClaw}"

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [install-openclaw] $*"; }

# ── Load .env for API key ─────────────────────────────────────────────────
ENV_FILE="${JAKECLAW_DIR}/config/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

# ── Check for existing install ────────────────────────────────────────────
if su - "${JAKE_USER}" -c "command -v claude >/dev/null 2>&1"; then
  log "OpenClaw (claude) already installed — skipping"
  su - "${JAKE_USER}" -c "claude --version" || true
  exit 0
fi

log "Installing OpenClaw (Claude Code CLI)..."

# ── Install via npm (requires Node.js 24+) ────────────────────────────────
# USER INPUT REQUIRED: ANTHROPIC_API_KEY must be set in environment or .env
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  log "WARNING: ANTHROPIC_API_KEY not set — OpenClaw will install but cannot authenticate."
  log "         Set it in ${JAKECLAW_DIR}/config/.env  (see .env.example)"
fi

npm install -g @anthropic-ai/claude-code --quiet

# ── Write API key to jake's environment ──────────────────────────────────
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  su - "${JAKE_USER}" -c "
    if ! grep -q ANTHROPIC_API_KEY ~/.bashrc 2>/dev/null; then
      echo 'export ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}' >> ~/.bashrc
    fi
  "
fi

# ── Verify ────────────────────────────────────────────────────────────────
if command -v claude >/dev/null 2>&1; then
  log "OpenClaw installed: $(claude --version)"
else
  log "ERROR: claude command not found after install" >&2
  exit 1
fi

# ── Copy OpenClaw config ──────────────────────────────────────────────────
OPENCLAW_CONFIG="${JAKECLAW_DIR}/config/openclaw-config.json"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  mkdir -p "${JAKE_HOME}/.claude"
  cp "$OPENCLAW_CONFIG" "${JAKE_HOME}/.claude/settings.json"
  chown -R "${JAKE_USER}:${JAKE_USER}" "${JAKE_HOME}/.claude"
  log "OpenClaw config deployed to ${JAKE_HOME}/.claude/settings.json"
fi

log "OpenClaw installation complete"
