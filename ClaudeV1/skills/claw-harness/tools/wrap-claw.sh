#!/usr/bin/env bash
# =============================================================================
# wrap-claw.sh — Wrapper for /usr/local/bin/claw
#
# Usage: wrap-claw.sh <command> [args...]
#
# Logs every invocation to /Jake-data/logs/claw-invocations.log
# Returns structured output (JSON where possible, else plain text).
# On error, prints to stderr and exits non-zero.
# =============================================================================
set -euo pipefail

CLAW_BIN="${CLAW_BIN:-/usr/local/bin/claw}"
JAKE_DATA="${JAKE_DATA:-/Jake-data}"
LOG_DIR="${JAKE_DATA}/logs"
LOG_FILE="${LOG_DIR}/claw-invocations.log"

# ── Logging helper ────────────────────────────────────────────────────────
mkdir -p "${LOG_DIR}"
log() {
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [wrap-claw] $*" | tee -a "${LOG_FILE}"
}

# ── Validate binary ───────────────────────────────────────────────────────
if [[ ! -x "${CLAW_BIN}" ]]; then
  log "ERROR: claw binary not found at ${CLAW_BIN}" >&2
  echo '{"error":"claw binary not found","binary":"'"${CLAW_BIN}"'"}' >&2
  exit 1
fi

# ── Parse args ────────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  echo "Usage: wrap-claw.sh <command> [args...]" >&2
  exit 1
fi

COMMAND="$1"
shift
ARGS=("$@")

# ── Safety gate for destructive commands ─────────────────────────────────
# These commands are marked destructive; the SKILL.md requires the agent
# to have obtained explicit user confirmation before calling this wrapper
# with a destructive command.
# The wrapper itself does NOT re-prompt (confirmation already done at skill
# level) but it records the invocation prominently.
DESTRUCTIVE_CMDS=("self-update" "install-plugin" "reset" "delete" "remove")
for dcmd in "${DESTRUCTIVE_CMDS[@]}"; do
  if [[ "${COMMAND}" == "${dcmd}" ]]; then
    log "DESTRUCTIVE COMMAND: ${COMMAND} ${ARGS[*]:-}"
    echo "[wrap-claw] NOTICE: Executing destructive command '${COMMAND}' — ensure user confirmed" | \
      tee -a "${LOG_FILE}"
    break
  fi
done

# ── Execute ───────────────────────────────────────────────────────────────
log "Executing: ${CLAW_BIN} ${COMMAND} ${ARGS[*]:-}"

TMPOUT=$(mktemp)
TMPERR=$(mktemp)
trap 'rm -f "${TMPOUT}" "${TMPERR}"' EXIT

EXIT_CODE=0
"${CLAW_BIN}" "${COMMAND}" "${ARGS[@]:-}" > "${TMPOUT}" 2> "${TMPERR}" || EXIT_CODE=$?

STDOUT=$(cat "${TMPOUT}")
STDERR=$(cat "${TMPERR}")

# ── Log result ────────────────────────────────────────────────────────────
if [[ ${EXIT_CODE} -eq 0 ]]; then
  log "SUCCESS: ${COMMAND} (exit 0)"
else
  log "FAILURE: ${COMMAND} (exit ${EXIT_CODE})"
  log "STDERR: ${STDERR}"
fi

# ── Output ────────────────────────────────────────────────────────────────
echo "${STDOUT}"
if [[ -n "${STDERR}" ]]; then
  echo "${STDERR}" >&2
fi

exit ${EXIT_CODE}
