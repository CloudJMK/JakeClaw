#!/usr/bin/env bash
set -euo pipefail

JAKE_USER=${JAKE_USER:-jake}
CONTINUE_CONF_SRC="/JakeClaw/GPTv1/config/continue-config.yaml"
CONTINUE_DIR="/home/$JAKE_USER/.continue"

if [ ! -d "$CONTINUE_DIR" ]; then
  mkdir -p "$CONTINUE_DIR"
  chown $JAKE_USER:$JAKE_USER "$CONTINUE_DIR" || true
fi

# Install Continue extension via code CLI or code-server
su - $JAKE_USER -c "code --install-extension Continue.continue" 2>/dev/null || \
su - $JAKE_USER -c "code-server --install-extension Continue.continue" 2>/dev/null || echo "Continue extension install failed or not available in this environment"

if [ -f "$CONTINUE_CONF_SRC" ]; then
  cp "$CONTINUE_CONF_SRC" "$CONTINUE_DIR/config.yaml" || cp "$CONTINUE_CONF_SRC" "$CONTINUE_DIR/config.json" || true
  chown $JAKE_USER:$JAKE_USER "$CONTINUE_DIR/config.yaml" 2>/dev/null || true
fi

echo "Continue.dev install skeleton complete (check $CONTINUE_DIR)."
