#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${JAKE_DATA_DIR:-/Jake-data}/logs/skills"
LOG_FILE="${LOG_DIR}/claw-harness.log"
mkdir -p "${LOG_DIR}"

if [[ $# -lt 1 ]]; then
  echo "usage: wrap-claw.sh <command> [args...]" >&2
  exit 1
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '[%s] claw %s\n' "${timestamp}" "$*" >> "${LOG_FILE}"

exec /usr/local/bin/claw "$@"
