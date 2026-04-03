#!/usr/bin/env bash
set -euo pipefail

# This script scaffolds LiteLLM configuration and a systemd service for an OpenAI-compatible API wrapper.
# NOTE: Running this script will attempt to write to /etc and enable a systemd service; review before running.

CONFIG_PATH="/etc/litellm/config.yaml"
SERVICE_PATH="/etc/systemd/system/jake-api.service"

cat > /tmp/litellm-config.yaml <<'EOF'
model_list:
  - model_name: jake-claw
    litellm_params:
      model: custom/jake-claw
      api_base: http://localhost:8081
EOF

# Move into place (requires root)
mv /tmp/litellm-config.yaml "$CONFIG_PATH" || true

cat > /tmp/jake-api.service <<'EOF'
[Unit]
Description=Jake OpenAI-Compatible API Wrapper (LiteLLM)
After=network.target

[Service]
Type=simple
User=${JAKE_USER:-jake}
ExecStart=/usr/local/bin/litellm --config /etc/litellm/config.yaml --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

mv /tmp/jake-api.service "$SERVICE_PATH" || true
systemctl daemon-reload || true
# Do not enable automatically in the scaffold; let user review first.

echo "Wrote LiteLLM config to $CONFIG_PATH and systemd unit to $SERVICE_PATH (scaffold). Review before enabling."
