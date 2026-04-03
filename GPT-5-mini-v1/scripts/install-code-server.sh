#!/usr/bin/env bash
set -euo pipefail

if ! command -v code-server >/dev/null 2>&1; then
  echo "Installing code-server..."
  curl -fsSL https://code-server.dev/install.sh | sh
else
  echo "code-server already installed"
fi

# Enable systemd service for jake user (adjust user name if different)
JAKE_USER=${JAKE_USER:-jake}
if id "$JAKE_USER" >/dev/null 2>&1; then
  systemctl enable --now "code-server@$JAKE_USER" || true
fi

echo "code-server install complete."
