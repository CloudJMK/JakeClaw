#!/usr/bin/env bash
set -euo pipefail

CLAW_BIN=${CLAW_BIN:-/usr/local/bin/claw}
if [ ! -x "$CLAW_BIN" ]; then
  echo "claw binary not found at $CLAW_BIN" >&2
  exit 1
fi

# Pass through arguments to claw; this wrapper captures stdout/stderr
"$CLAW_BIN" "$@"
EXIT_CODE=$?
exit $EXIT_CODE
