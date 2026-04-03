#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git build-essential curl wget python3 python3-venv python3-pip nodejs npm chromium-browser

# Install Node.js 24+ via NodeSource if available (placeholder)
# TODO: Add NodeSource setup for Node 24 if desired

# Ensure rustup for the jake user will be handled in install-claw-code.sh if needed

echo "Dev environment packages installed (skeleton)."
