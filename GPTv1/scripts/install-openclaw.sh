#!/usr/bin/env bash
set -euo pipefail

# Install OpenClaw (skeleton) — idempotent
REPO_URL=${OPENCLAW_REPO:-"https://github.com/openclaw/openclaw.git"}
DEST=/opt/openclaw

if [ -d "$DEST" ]; then
  echo "OpenClaw already cloned at $DEST"
else
  echo "Cloning OpenClaw from $REPO_URL to $DEST"
  git clone "$REPO_URL" "$DEST" || { echo "git clone failed"; exit 1; }
fi

# Example: create virtualenv and install requirements (adjust to upstream)
if [ ! -d "$DEST/venv" ]; then
  python3 -m venv "$DEST/venv"
  source "$DEST/venv/bin/activate"
  pip install --upgrade pip
  if [ -f "$DEST/requirements.txt" ]; then
    pip install -r "$DEST/requirements.txt"
  fi
  deactivate
fi

echo "OpenClaw install (skeleton) completed. Verify with: $DEST/venv/bin/python -m openclaw --version (adjust as needed)"
