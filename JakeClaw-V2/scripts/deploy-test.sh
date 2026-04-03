#!/usr/bin/env bash
# deploy-test.sh — Smoke test suite for Jake VM deployment
#
# Run this after bootstrap to verify everything is working correctly.
# Usage: bash deploy-test.sh [--verbose] [--suite <name>]
#   --verbose      Show detail for every check
#   --suite <name> Run only one suite: user | mounts | versions | services | api | continue | timer

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
VERBOSE=false
ONLY_SUITE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose) VERBOSE=true; shift ;;
    --suite) ONLY_SUITE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}PASS${RESET}  %s\n" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}FAIL${RESET}  %s\n" "$1"
  if [[ "$VERBOSE" == "true" && -n "${2:-}" ]]; then
    echo "        Detail: $2"
  fi
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf "  ${YELLOW}SKIP${RESET}  %s\n" "$1"
}

suite() {
  local name="$1"
  if [[ -n "$ONLY_SUITE" && "$ONLY_SUITE" != "$name" ]]; then
    return 1  # Signal to skip this suite
  fi
  printf "\n${BLUE}=== Suite: %s ===${RESET}\n" "$name"
  return 0
}

# ---------------------------------------------------------------------------
# Load environment
# ---------------------------------------------------------------------------
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.env" 2>/dev/null && pwd)/../../.env" || ENV_FILE=""
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANDIDATE_ENV="${REPO_DIR}/../.env"
if [[ -f "$CANDIDATE_ENV" ]]; then
  set -a; source "$CANDIDATE_ENV"; set +a  # shellcheck source=/dev/null
fi

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKE_DATA_DIR="${JAKE_DATA_DIR:-/Jake-data}"
JAKE_API_PORT="${JAKE_API_PORT:-8000}"
CODE_SERVER_BIND_ADDR="${CODE_SERVER_BIND_ADDR:-0.0.0.0:8080}"
CODE_SERVER_PORT="${CODE_SERVER_BIND_ADDR##*:}"
CLAW_SERVER_PORT="${CLAW_SERVER_PORT:-8081}"

echo ""
echo "========================================"
echo " JakeClaw-V2 Deployment Test Suite"
echo " $(date)"
echo "========================================"

# ---------------------------------------------------------------------------
# Suite: user
# ---------------------------------------------------------------------------
if suite "user"; then
  # Jake user exists
  if id "$JAKE_USER" &>/dev/null; then
    pass "User '${JAKE_USER}' exists"
  else
    fail "User '${JAKE_USER}' not found"
  fi

  # Home directory
  if [[ -d "$JAKE_HOME" ]]; then
    pass "Home directory ${JAKE_HOME} exists"
  else
    fail "Home directory ${JAKE_HOME} missing"
  fi

  # Sudo access
  if sudo -l -U "$JAKE_USER" 2>/dev/null | grep -q NOPASSWD; then
    pass "Passwordless sudo configured for ${JAKE_USER}"
  else
    fail "Passwordless sudo NOT configured for ${JAKE_USER}"
  fi

  # JakeClaw repo
  if [[ -d "${REPO_DIR}/.git" ]]; then
    pass "JakeClaw repo present at ${REPO_DIR}"
  else
    fail "JakeClaw repo not found at ${REPO_DIR}"
  fi
fi

# ---------------------------------------------------------------------------
# Suite: mounts
# ---------------------------------------------------------------------------
if suite "mounts"; then
  if mountpoint -q "$JAKE_DATA_DIR" 2>/dev/null; then
    pass "${JAKE_DATA_DIR} is a mounted volume"
  else
    skip "${JAKE_DATA_DIR} is not a separate mount (may be acceptable in dev)"
  fi

  if [[ -w "$JAKE_DATA_DIR" ]]; then
    pass "${JAKE_DATA_DIR} is writable"
  else
    fail "${JAKE_DATA_DIR} is not writable"
  fi

  for d in logs skills workspace; do
    if [[ -d "${JAKE_DATA_DIR}/${d}" ]]; then
      pass "${JAKE_DATA_DIR}/${d} directory exists"
    else
      fail "${JAKE_DATA_DIR}/${d} directory missing"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Suite: versions
# ---------------------------------------------------------------------------
if suite "versions"; then
  check_cmd() {
    local cmd="$1"; local label="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
      local ver
      ver=$("$cmd" --version 2>&1 | head -1)
      pass "${label}: ${ver}"
    else
      fail "${label} not found in PATH"
    fi
  }

  check_cmd git
  check_cmd node "Node.js"
  check_cmd npm
  check_cmd python3
  check_cmd pip3
  check_cmd jq
  check_cmd code-server

  # cargo (may be in jake's home)
  if command -v cargo &>/dev/null || [[ -x "${JAKE_HOME}/.cargo/bin/cargo" ]]; then
    CARGO="${JAKE_HOME}/.cargo/bin/cargo"
    [[ ! -x "$CARGO" ]] && CARGO="cargo"
    pass "cargo: $($CARGO --version 2>&1 | head -1)"
  else
    skip "cargo not found (Rust may not be installed)"
  fi

  # claw
  if [[ -x /usr/local/bin/claw ]]; then
    pass "claw: $(/usr/local/bin/claw --version 2>&1 | head -1 || echo 'installed')"
  else
    fail "claw binary not found at /usr/local/bin/claw"
  fi

  # claude (openclaw)
  if command -v claude &>/dev/null; then
    pass "claude (openclaw): $(claude --version 2>&1 | head -1 || echo 'installed')"
  else
    fail "claude (openclaw) not found"
  fi
fi

# ---------------------------------------------------------------------------
# Suite: services
# ---------------------------------------------------------------------------
if suite "services"; then
  check_service() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      pass "${svc} is active"
    elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
      fail "${svc} is enabled but NOT running"
    else
      fail "${svc} is not enabled or running"
    fi
  }

  check_service "code-server@${JAKE_USER}"
  check_service "jake-api.service"
  check_service "claw-code.service"

  # Timer (not a running service — check enabled)
  if systemctl is-enabled --quiet jake-self-improve.timer 2>/dev/null; then
    pass "jake-self-improve.timer is enabled"
  else
    fail "jake-self-improve.timer is not enabled"
  fi
fi

# ---------------------------------------------------------------------------
# Suite: api
# ---------------------------------------------------------------------------
if suite "api"; then
  http_check() {
    local label="$1"; local url="$2"; local expected="${3:-200}"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")
    if [[ "$status" == "$expected" ]]; then
      pass "${label} responded HTTP ${status}"
    else
      fail "${label} — expected HTTP ${expected}, got ${status}" "$url"
    fi
  }

  http_check "Jake API (:${JAKE_API_PORT}/v1/models)" \
    "http://localhost:${JAKE_API_PORT}/v1/models"
  http_check "code-server (:${CODE_SERVER_PORT})" \
    "http://localhost:${CODE_SERVER_PORT}"
  # claw-code health (may return 404 if /health not implemented — that's OK)
  if curl -s --connect-timeout 5 "http://localhost:${CLAW_SERVER_PORT}" &>/dev/null; then
    pass "claw-code server (:${CLAW_SERVER_PORT}) is reachable"
  else
    fail "claw-code server (:${CLAW_SERVER_PORT}) is not reachable"
  fi
fi

# ---------------------------------------------------------------------------
# Suite: continue
# ---------------------------------------------------------------------------
if suite "continue"; then
  CONTINUE_LINK="${JAKE_HOME}/.continue"
  CONTINUE_TARGET="${JAKE_DATA_DIR}/.continue"

  if [[ -L "$CONTINUE_LINK" ]]; then
    pass "~/.continue is a symlink"
    LINK_DEST=$(readlink "$CONTINUE_LINK")
    if [[ "$LINK_DEST" == "$CONTINUE_TARGET" ]]; then
      pass "Symlink points to ${CONTINUE_TARGET} (persistent volume)"
    else
      fail "Symlink points to ${LINK_DEST} (expected ${CONTINUE_TARGET})"
    fi
  elif [[ -d "$CONTINUE_LINK" ]]; then
    fail "~/.continue is a plain directory (not symlinked to /Jake-data)"
  else
    fail "~/.continue does not exist"
  fi

  if [[ -f "${CONTINUE_TARGET}/config.yaml" ]]; then
    pass "Continue config.yaml present"
  else
    fail "Continue config.yaml missing at ${CONTINUE_TARGET}/config.yaml"
  fi
fi

# ---------------------------------------------------------------------------
# Suite: timer
# ---------------------------------------------------------------------------
if suite "timer"; then
  if systemctl is-enabled --quiet jake-self-improve.timer 2>/dev/null; then
    NEXT=$(systemctl show jake-self-improve.timer --property=NextElapseUSecRealtime 2>/dev/null \
      | cut -d= -f2 || echo "unknown")
    pass "jake-self-improve.timer enabled (next: ${NEXT})"
  else
    fail "jake-self-improve.timer not found or not enabled"
  fi

  LOG_FILE="${JAKE_DATA_DIR}/logs/self-improvement.log"
  if [[ -f "$LOG_FILE" ]]; then
    LAST_LINE=$(tail -1 "$LOG_FILE")
    pass "self-improvement.log exists (last: ${LAST_LINE})"
  else
    skip "self-improvement.log not yet created (timer hasn't run)"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo ""
echo "========================================"
printf " Results: ${GREEN}%d PASS${RESET}  ${RED}%d FAIL${RESET}  ${YELLOW}%d SKIP${RESET}  / %d total\n" \
  "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$TOTAL"
echo "========================================"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "Some checks failed. Re-run with --verbose for details."
  exit 1
fi

exit 0
