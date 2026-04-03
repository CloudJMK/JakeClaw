#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "setup-jake-api.sh must run as root" >&2
  exit 1
fi

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force=1|--force) FORCE=1 ;;
  esac
done

if [[ "${FORCE}" -ne 1 ]]; then
  read -r -p "Install or update the Jake API wrapper? [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || exit 1
fi

python3 -m pip install "litellm[proxy]"
install -d -m 0755 /etc/litellm

cat > /etc/litellm/config.yaml <<EOF
model_list:
  - model_name: jake-claw
    litellm_params:
      model: openai/jake-claw
      api_base: http://127.0.0.1:8081
      api_key: ${JAKE_API_KEY:-dummy-key}

general_settings:
  master_key: ${LITELLM_MASTER_KEY:-replace-me}
EOF

cat > /etc/systemd/system/jake-api.service <<EOF
[Unit]
Description=Jake OpenAI-compatible API wrapper
After=network-online.target claw-code.service
Wants=network-online.target

[Service]
Type=simple
User=${JAKE_USER:-jake}
EnvironmentFile=-${JAKE_REPO_DIR:-/opt/JakeClaw}/config/.env
ExecStart=/usr/local/bin/litellm --config /etc/litellm/config.yaml --host ${JAKE_API_HOST:-127.0.0.1} --port ${JAKE_API_PORT:-8000}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now jake-api.service || true
