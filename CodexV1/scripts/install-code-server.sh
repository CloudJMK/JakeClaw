#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "install-code-server.sh must run as root" >&2
  exit 1
fi

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force=1|--force) FORCE=1 ;;
  esac
done

if [[ "${FORCE}" -ne 1 ]]; then
  read -r -p "Install or reconfigure code-server? [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || exit 1
fi

if ! command -v code-server >/dev/null 2>&1; then
  curl -fsSL https://code-server.dev/install.sh | sh
fi

install -d -o "${JAKE_USER:-jake}" -g "${JAKE_USER:-jake}" "${JAKE_HOME:-/home/jake}/.config/code-server"
cat > "${JAKE_HOME:-/home/jake}/.config/code-server/config.yaml" <<EOF
bind-addr: ${CODE_SERVER_BIND_ADDR:-0.0.0.0:8080}
auth: ${CODE_SERVER_AUTH:-password}
password: ${CODE_SERVER_PASSWORD:-replace-me}
cert: false
EOF
chown "${JAKE_USER:-jake}:${JAKE_USER:-jake}" "${JAKE_HOME:-/home/jake}/.config/code-server/config.yaml"

systemctl enable --now "code-server@${JAKE_USER:-jake}" || true
