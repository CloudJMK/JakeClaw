#!/usr/bin/env bash
# install-dev-env.sh — Install base development tools inside the Jake VM
#
# Installs: git, build essentials, Python 3, Node.js 24, Rust, jq, and
# optional extras controlled by feature flags in ../.env.

set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: Must run as root" >&2; exit 1; }

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a  # shellcheck source=/dev/null
fi

JAKE_USER="${JAKE_USER:-jake}"
INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
INSTALL_CHROMIUM="${INSTALL_CHROMIUM:-false}"
INSTALL_PLAYWRIGHT="${INSTALL_PLAYWRIGHT:-false}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] install-dev-env: $*"; }
log "Starting"

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# System packages
# ---------------------------------------------------------------------------
apt-get update -qq
apt-get install -y --no-install-recommends \
  git curl wget unzip jq htop tmux vim \
  build-essential pkg-config \
  python3 python3-pip python3-venv python3-dev \
  ca-certificates gnupg lsb-release \
  flock

# ---------------------------------------------------------------------------
# Node.js 24 (via NodeSource — idempotent)
# ---------------------------------------------------------------------------
REQUIRED_NODE_MAJOR=24
INSTALLED_NODE_MAJOR=0
if command -v node &>/dev/null; then
  INSTALLED_NODE_MAJOR=$(node --version | sed 's/v\([0-9]*\).*/\1/')
fi

if [[ "$INSTALLED_NODE_MAJOR" -lt "$REQUIRED_NODE_MAJOR" ]]; then
  log "Installing Node.js ${REQUIRED_NODE_MAJOR}"
  curl -fsSL "https://deb.nodesource.com/setup_${REQUIRED_NODE_MAJOR}.x" | bash -
  apt-get install -y --no-install-recommends nodejs
else
  log "Node.js ${INSTALLED_NODE_MAJOR} already satisfies >= ${REQUIRED_NODE_MAJOR}"
fi

# ---------------------------------------------------------------------------
# Rust (for jake user — idempotent via rustup)
# ---------------------------------------------------------------------------
CARGO_BIN="/home/${JAKE_USER}/.cargo/bin"
if [[ ! -x "${CARGO_BIN}/cargo" ]]; then
  log "Installing Rust via rustup for ${JAKE_USER}"
  sudo -u "$JAKE_USER" bash -c \
    'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path'
else
  log "Rust already installed for ${JAKE_USER}"
fi

# Make cargo available system-wide for scripts running as root
if [[ ! -L /usr/local/bin/cargo ]]; then
  ln -sf "${CARGO_BIN}/cargo" /usr/local/bin/cargo || true
fi

# ---------------------------------------------------------------------------
# Python pip upgrade
# ---------------------------------------------------------------------------
python3 -m pip install --upgrade pip --quiet --break-system-packages 2>/dev/null \
  || python3 -m pip install --upgrade pip --quiet

# ---------------------------------------------------------------------------
# Optional feature installs
# ---------------------------------------------------------------------------
if [[ "$INSTALL_DOCKER" == "true" ]]; then
  if ! command -v docker &>/dev/null; then
    log "Installing Docker"
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "$JAKE_USER"
  else
    log "Docker already installed"
  fi
fi

if [[ "$INSTALL_CHROMIUM" == "true" ]]; then
  log "Installing Chromium"
  apt-get install -y --no-install-recommends chromium-browser
fi

if [[ "$INSTALL_PLAYWRIGHT" == "true" ]]; then
  log "Installing Playwright"
  sudo -u "$JAKE_USER" bash -c \
    "cd ~ && npm install -g playwright && npx playwright install-deps"
fi

log "Done"
