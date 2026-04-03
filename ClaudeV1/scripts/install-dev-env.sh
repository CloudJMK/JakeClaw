#!/usr/bin/env bash
# =============================================================================
# install-dev-env.sh — Install full dev environment for JakeClaw
# Idempotent: checks for existing installs before acting.
# Must run as root.
# =============================================================================
set -euo pipefail
[[ "${EUID}" -ne 0 ]] && { echo "Must run as root" >&2; exit 1; }

JAKE_USER="${JAKE_USER:-jake}"

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [install-dev-env] $*"; }
log "Starting dev environment installation"

export DEBIAN_FRONTEND=noninteractive

# ── System packages ────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y --no-install-recommends \
  git curl wget unzip jq htop tmux vim \
  build-essential pkg-config \
  python3 python3-pip python3-venv python3-dev \
  ca-certificates gnupg lsb-release \
  chromium-browser \
  flock \
  libssl-dev libffi-dev \
  2>/dev/null || true

# ── Node.js 24+ (via NodeSource) ───────────────────────────────────────────
if ! command -v node >/dev/null 2>&1 || [[ "$(node --version | cut -d. -f1 | tr -d 'v')" -lt 24 ]]; then
  log "Installing Node.js 24..."
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y nodejs
else
  log "Node.js $(node --version) already installed — skipping"
fi

# ── Rust (rustup, for jake user) ──────────────────────────────────────────
if ! su - "${JAKE_USER}" -c "command -v rustup >/dev/null 2>&1"; then
  log "Installing Rust via rustup for ${JAKE_USER}..."
  su - "${JAKE_USER}" -c "
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    echo 'source \$HOME/.cargo/env' >> ~/.bashrc
  "
else
  log "Rust/rustup already installed for ${JAKE_USER} — skipping"
fi

# ── Python: upgrade pip and install common tools ──────────────────────────
python3 -m pip install --quiet --break-system-packages --upgrade pip setuptools wheel 2>/dev/null || \
  python3 -m pip install --quiet --upgrade pip setuptools wheel

log "Dev environment installation complete"
