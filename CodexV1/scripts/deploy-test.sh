#!/usr/bin/env bash
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

report() {
  local status="$1"
  local label="$2"
  case "${status}" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
  esac
  printf '[%s] %s\n' "${status}" "${label}"
}

check_cmd() {
  local label="$1"
  local cmd="$2"
  if bash -lc "${cmd}" >/dev/null 2>&1; then
    report PASS "${label}"
  else
    report FAIL "${label}"
  fi
}

check_optional_cmd() {
  local binary="$1"
  local label="$2"
  local cmd="$3"
  if ! command -v "${binary}" >/dev/null 2>&1; then
    report SKIP "${label} (${binary} not installed)"
    return
  fi
  check_cmd "${label}" "${cmd}"
}

check_cmd "Jake user exists" "id jake"
check_cmd "/Jake-data exists" "test -d /Jake-data"
check_cmd "sudo works non-interactively" "sudo -n true"

check_optional_cmd openclaw "OpenClaw version responds" "openclaw --version"
check_optional_cmd claw "Claw version responds" "claw --version"
check_optional_cmd code-server "code-server version responds" "code-server --version"
check_optional_cmd curl "Jake API models endpoint responds" "curl -fsS http://localhost:8000/v1/models"
check_optional_cmd systemctl "self-improvement timer present" "systemctl status jake-self-improve.timer"

echo
echo "Summary: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT} SKIP=${SKIP_COUNT}"
[[ "${FAIL_COUNT}" -eq 0 ]]
