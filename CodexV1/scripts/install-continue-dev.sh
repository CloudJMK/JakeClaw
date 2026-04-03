#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "install-continue-dev.sh must run as root" >&2
  exit 1
fi

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force=1|--force) FORCE=1 ;;
  esac
done

if [[ "${FORCE}" -ne 1 ]]; then
  read -r -p "Install Continue.dev extension and config? [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || exit 1
fi

if ! command -v code-server >/dev/null 2>&1 && ! command -v code >/dev/null 2>&1; then
  echo "code-server or code CLI is required before installing Continue.dev" >&2
  exit 1
fi

if command -v code-server >/dev/null 2>&1; then
  su - "${JAKE_USER:-jake}" -c "code-server --install-extension Continue.continue" || true
fi

if command -v code >/dev/null 2>&1; then
  su - "${JAKE_USER:-jake}" -c "code --install-extension Continue.continue" || true
fi

CONTINUE_DIR="${JAKE_HOME:-/home/jake}/.continue"
install -d -o "${JAKE_USER:-jake}" -g "${JAKE_USER:-jake}" "${CONTINUE_DIR}"
install -m 0644 "${JAKE_REPO_DIR:-/opt/JakeClaw}/config/continue-config.yaml" "${CONTINUE_DIR}/config.yaml"
chown "${JAKE_USER:-jake}:${JAKE_USER:-jake}" "${CONTINUE_DIR}/config.yaml"
