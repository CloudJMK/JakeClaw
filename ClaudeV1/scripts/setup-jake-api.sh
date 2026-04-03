#!/usr/bin/env bash
# =============================================================================
# setup-jake-api.sh — Install LiteLLM proxy as OpenAI-compatible API wrapper
#
# Provides http://localhost:8000/v1 — the endpoint Continue.dev and OpenClaw
# use to talk to Jake's backend (claw-code Axum server or direct model API).
#
# USER INPUT REQUIRED:
#   In config/.env, set ONE of the following routing options:
#
#   Option A (Local claw-code Axum server):
#     JAKE_API_BACKEND=claw-local
#     CLAW_SERVER_PORT=8081       ← port claw-code runs on
#
#   Option B (Direct Anthropic API via LiteLLM):
#     JAKE_API_BACKEND=anthropic
#     ANTHROPIC_API_KEY="{{ANTHROPIC_API_KEY}}"
#
#   Option C (OpenAI-compatible remote):
#     JAKE_API_BACKEND=openai
#     OPENAI_API_KEY="{{OPENAI_API_KEY}}"
#     OPENAI_API_BASE="{{OPENAI_API_BASE}}"    ← optional custom base
#
# Idempotent: checks for existing LiteLLM install and service.
# =============================================================================
set -euo pipefail
[[ "${EUID}" -ne 0 ]] && { echo "Must run as root" >&2; exit 1; }

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKECLAW_DIR="${JAKECLAW_DIR:-/JakeClaw}"
JAKE_API_PORT=8000

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [setup-jake-api] $*"; }

# ── Load .env ──────────────────────────────────────────────────────────────
ENV_FILE="${JAKECLAW_DIR}/config/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"  # shellcheck source=/dev/null

JAKE_API_BACKEND="${JAKE_API_BACKEND:-claw-local}"
CLAW_SERVER_PORT="${CLAW_SERVER_PORT:-8081}"

# ── Install LiteLLM ────────────────────────────────────────────────────────
if ! command -v litellm >/dev/null 2>&1; then
  log "Installing LiteLLM proxy..."
  python3 -m pip install --quiet "litellm[proxy]" --break-system-packages 2>/dev/null || \
  python3 -m pip install --quiet "litellm[proxy]"
else
  log "LiteLLM already installed: $(litellm --version 2>/dev/null || echo 'unknown')"
fi

# ── Write LiteLLM config ───────────────────────────────────────────────────
mkdir -p /etc/litellm

case "${JAKE_API_BACKEND}" in
  claw-local)
    log "Configuring LiteLLM to route to local claw-code server on port ${CLAW_SERVER_PORT}"
    cat > /etc/litellm/config.yaml << EOF
# LiteLLM proxy config — routing to local claw-code Axum server
# USER INPUT: ensure claw-code.service is running on port ${CLAW_SERVER_PORT}
model_list:
  - model_name: jake-claw
    litellm_params:
      model: openai/jake-claw
      api_base: http://localhost:${CLAW_SERVER_PORT}/v1
      api_key: jake-internal         # claw-code ignores this; any non-empty value works

  - model_name: jake-autocomplete
    litellm_params:
      model: openai/jake-claw
      api_base: http://localhost:${CLAW_SERVER_PORT}/v1
      api_key: jake-internal

general_settings:
  master_key: jake-proxy-internal    # internal only; not exposed outside VM
EOF
    ;;

  anthropic)
    log "Configuring LiteLLM to route to Anthropic API"
    # USER INPUT REQUIRED: ANTHROPIC_API_KEY must be set in config/.env
    cat > /etc/litellm/config.yaml << EOF
# LiteLLM proxy config — routing to Anthropic API
# USER INPUT REQUIRED: set ANTHROPIC_API_KEY in config/.env
model_list:
  - model_name: jake-claw
    litellm_params:
      model: anthropic/claude-sonnet-4-6
      api_key: "${ANTHROPIC_API_KEY:-ANTHROPIC_API_KEY_REQUIRED}"

general_settings:
  master_key: jake-proxy-internal
EOF
    ;;

  openai)
    log "Configuring LiteLLM to route to OpenAI-compatible API"
    # USER INPUT REQUIRED: OPENAI_API_KEY must be set
    cat > /etc/litellm/config.yaml << EOF
# LiteLLM proxy config — routing to OpenAI-compatible API
# USER INPUT REQUIRED: set OPENAI_API_KEY (and optionally OPENAI_API_BASE) in config/.env
model_list:
  - model_name: jake-claw
    litellm_params:
      model: openai/gpt-4o
      api_key: "${OPENAI_API_KEY:-OPENAI_API_KEY_REQUIRED}"
      api_base: "${OPENAI_API_BASE:-https://api.openai.com/v1}"

general_settings:
  master_key: jake-proxy-internal
EOF
    ;;
esac

chmod 640 /etc/litellm/config.yaml
chown root:"${JAKE_USER}" /etc/litellm/config.yaml

# ── Systemd service ────────────────────────────────────────────────────────
cat > /etc/systemd/system/jake-api.service << EOF
[Unit]
Description=Jake OpenAI-Compatible API Proxy (LiteLLM)
After=network.target claw-code.service

[Service]
Type=simple
User=${JAKE_USER}
ExecStart=$(command -v litellm) --config /etc/litellm/config.yaml --port ${JAKE_API_PORT} --host 0.0.0.0
Restart=always
RestartSec=5
Environment="HOME=${JAKE_HOME}"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now jake-api.service

log "Jake API proxy running on port ${JAKE_API_PORT}"
log "Test: curl http://localhost:${JAKE_API_PORT}/v1/models"
