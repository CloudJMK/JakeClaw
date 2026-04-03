#!/usr/bin/env bash
# setup-jake-api.sh — Install and configure the Jake API proxy (LiteLLM)
#
# LiteLLM provides an OpenAI-compatible /v1 endpoint on port 8000.
# Backend is controlled by JAKE_API_BACKEND:
#   claw-local  — routes to claw-code server at localhost:8081 (default)
#   anthropic   — routes directly to Anthropic API
#   openai      — routes to OpenAI or compatible endpoint
#   custom      — uses CUSTOM_MODEL_API_BASE

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: Must run as root" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi  # shellcheck source=/dev/null

JAKE_API_BACKEND="${JAKE_API_BACKEND:-claw-local}"
JAKE_API_PORT="${JAKE_API_PORT:-8000}"
JAKE_API_KEY="${JAKE_API_KEY:-jake-api-secret}"
LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-sk-litellm-master-key}"
JAKE_MODEL_NAME="${JAKE_MODEL_NAME:-claude-sonnet-4-6}"
CLAW_SERVER_PORT="${CLAW_SERVER_PORT:-8081}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
CUSTOM_MODEL_API_BASE="${CUSTOM_MODEL_API_BASE:-}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] setup-jake-api: $*"; }
log "Starting (backend=${JAKE_API_BACKEND})"

# ---------------------------------------------------------------------------
# Install LiteLLM (idempotent)
# ---------------------------------------------------------------------------
if ! command -v litellm &>/dev/null; then
  log "Installing LiteLLM"
  pip3 install litellm --quiet --break-system-packages 2>/dev/null \
    || pip3 install litellm --quiet
else
  log "LiteLLM already installed: $(litellm --version 2>/dev/null || echo 'version unknown')"
fi

# ---------------------------------------------------------------------------
# Build LiteLLM config based on backend selection
# ---------------------------------------------------------------------------
mkdir -p /etc/litellm

case "$JAKE_API_BACKEND" in
  claw-local)
    PROVIDER="openai"
    MODEL_STR="openai/${JAKE_MODEL_NAME}"
    API_BASE="http://localhost:${CLAW_SERVER_PORT}/v1"
    API_KEY_LINE="api_key: ${JAKE_API_KEY}"
    ;;
  anthropic)
    PROVIDER="anthropic"
    MODEL_STR="anthropic/${JAKE_MODEL_NAME}"
    API_BASE=""
    API_KEY_LINE="api_key: ${ANTHROPIC_API_KEY}"
    ;;
  openai)
    PROVIDER="openai"
    MODEL_STR="openai/${JAKE_MODEL_NAME}"
    API_BASE=""
    API_KEY_LINE="api_key: ${OPENAI_API_KEY}"
    ;;
  custom)
    PROVIDER="openai"
    MODEL_STR="openai/${JAKE_MODEL_NAME}"
    API_BASE="${CUSTOM_MODEL_API_BASE}"
    API_KEY_LINE="api_key: ${JAKE_API_KEY}"
    ;;
  *)
    log "ERROR: Unknown JAKE_API_BACKEND='${JAKE_API_BACKEND}'"
    log "       Must be one of: claw-local, anthropic, openai, custom"
    exit 1
    ;;
esac

# Write config (idempotent — overwrites to pick up backend changes)
{
  echo "model_list:"
  echo "  - model_name: jake"
  echo "    litellm_params:"
  echo "      model: ${MODEL_STR}"
  if [[ -n "$API_BASE" ]]; then
    echo "      api_base: ${API_BASE}"
  fi
  echo "      ${API_KEY_LINE}"
  echo ""
  echo "general_settings:"
  echo "  master_key: ${LITELLM_MASTER_KEY}"
  echo "  port: ${JAKE_API_PORT}"
  echo "  drop_params: true"
} > /etc/litellm/config.yaml

log "LiteLLM config written to /etc/litellm/config.yaml"

# ---------------------------------------------------------------------------
# Systemd service
# ---------------------------------------------------------------------------
LITELLM_BIN="$(command -v litellm)"

cat > /etc/systemd/system/jake-api.service << EOF
[Unit]
Description=Jake API proxy (LiteLLM)
After=network.target claw-code.service
Wants=claw-code.service

[Service]
Type=simple
ExecStart=${LITELLM_BIN} --config /etc/litellm/config.yaml
Restart=on-failure
RestartSec=15
StandardOutput=journal
StandardError=journal
Environment="HOME=/root"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now jake-api.service
log "jake-api.service enabled and started"
log "Test: curl http://localhost:${JAKE_API_PORT}/v1/models"

log "Done"
