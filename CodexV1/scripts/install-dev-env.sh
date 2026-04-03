#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "install-dev-env.sh must run as root" >&2
  exit 1
fi

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --force=1|--force) FORCE=1 ;;
  esac
done

export DEBIAN_FRONTEND=noninteractive

confirm_or_exit() {
  if [[ "${FORCE}" -eq 1 ]]; then
    return
  fi
  read -r -p "$1 [y/N] " reply
  [[ "${reply}" =~ ^[Yy]$ ]] || exit 1
}

confirm_or_exit "Install and update system development packages?"

apt-get update -y
apt-get install -y \
  git \
  curl \
  wget \
  jq \
  unzip \
  zip \
  build-essential \
  pkg-config \
  libssl-dev \
  python3 \
  python3-pip \
  python3-venv \
  pipx \
  tmux \
  htop \
  ripgrep \
  fd-find \
  ca-certificates \
  gnupg

if [[ "${INSTALL_CHROMIUM:-true}" == "true" ]]; then
  apt-get install -y chromium-browser || apt-get install -y chromium || true
fi

if [[ "${INSTALL_DOCKER:-true}" == "true" && ! -x /usr/bin/docker ]]; then
  apt-get install -y docker.io docker-compose-v2 || true
  systemctl enable --now docker || true
  usermod -aG docker "${JAKE_USER:-jake}" || true
fi

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y nodejs
fi

if ! command -v cargo >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    su - "${JAKE_USER:-jake}" -c "sh -s -- -y --profile minimal"
fi

if [[ "${INSTALL_PLAYWRIGHT:-true}" == "true" ]]; then
  su - "${JAKE_USER:-jake}" -c "python3 -m pip install --user playwright" || true
  su - "${JAKE_USER:-jake}" -c "~/.local/bin/playwright install --with-deps chromium" || true
fi
