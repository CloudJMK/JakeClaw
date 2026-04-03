#!/usr/bin/env bash
set -euo pipefail

LOG=/var/log/jake-bootstrap.log
exec > >(tee -a "$LOG") 2>&1

if [ "$EUID" -ne 0 ]; then
  echo "bootstrap-Jake.sh must be run as root" >&2
  exit 1
fi

export JAKE_USER=${JAKE_USER:-jake}
export JAKE_HOME=${JAKE_HOME:-/home/$JAKE_USER}

echo "Starting Jake bootstrap: $(date)"

SCRIPTS_DIR="/opt/jake-scripts"
mkdir -p "$SCRIPTS_DIR"

# If modular scripts exist in the repo location, call them. These are idempotent checks.
SCRIPT_ROOT="/JakeClaw/GPTv1/scripts"

for s in install-openclaw.sh install-claw-code.sh install-dev-env.sh install-code-server.sh install-continue-dev.sh setup-jake-api.sh setup-self-improvement.sh expose-claw-tools.sh; do
  if [ -f "$SCRIPT_ROOT/$s" ]; then
    echo "Running $s"
    bash "$SCRIPT_ROOT/$s" || { echo "$s failed"; exit 1; }
  else
    echo "Skipping $s (not found at $SCRIPT_ROOT)"
  fi
done

echo "Bootstrap complete: $(date)"
exit 0
