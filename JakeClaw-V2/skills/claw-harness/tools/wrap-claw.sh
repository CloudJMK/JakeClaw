#!/usr/bin/env bash
# wrap-claw.sh — Thin wrapper around the claw binary with logging
#
# Called by the claw_harness skill. Logs every invocation and exits
# non-zero on failure so the skill can report errors to Jake.

set -euo pipefail

CLAW_BIN="${CLAW_BIN:-/usr/local/bin/claw}"
JAKE_DATA_DIR="${JAKE_DATA_DIR:-/Jake-data}"
LOG_FILE="${JAKE_DATA_DIR}/logs/claw-invocations.log"

mkdir -p "$(dirname "$LOG_FILE")"

COMMAND=""
PROJECT_PATH="${JAKE_DATA_DIR}/workspace"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --command)      COMMAND="$2";       shift 2 ;;
    --project-path) PROJECT_PATH="$2";  shift 2 ;;
    --args)         shift; EXTRA_ARGS+=("$@"); break ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

[[ -n "$COMMAND" ]] || { echo "Usage: wrap-claw.sh --command <cmd> [--project-path <path>] [--args ...]" >&2; exit 1; }
[[ -x "$CLAW_BIN" ]] || { echo "ERROR: claw binary not found at ${CLAW_BIN}" >&2; exit 1; }

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[${TIMESTAMP}] INVOKE command=${COMMAND} path=${PROJECT_PATH} args=${EXTRA_ARGS[*]:-}" \
  >> "$LOG_FILE"

cd "$PROJECT_PATH"
"$CLAW_BIN" "$COMMAND" "${EXTRA_ARGS[@]}"
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "[${TIMESTAMP}] FAIL  command=${COMMAND} exit=${EXIT_CODE}" >> "$LOG_FILE"
  exit $EXIT_CODE
fi

echo "[${TIMESTAMP}] OK    command=${COMMAND}" >> "$LOG_FILE"
