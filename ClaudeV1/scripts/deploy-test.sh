#!/usr/bin/env bash
# =============================================================================
# deploy-test.sh — JakeClaw post-deployment smoke tests
#
# Non-destructive read-only checks. Run as the jake user (not root).
# Prints a PASS/FAIL summary and exits 0 on full success, 1 on any failure.
#
# Usage:
#   bash /JakeClaw/scripts/deploy-test.sh
#   bash /JakeClaw/scripts/deploy-test.sh --verbose
#   bash /JakeClaw/scripts/deploy-test.sh --suite versions   # run one suite only
#
# Test suites:
#   user         — jake user, home dir, sudoers
#   mounts       — /Jake-data mounted and writable
#   versions     — tool versions (git, node, python, rust, claw, code-server)
#   services     — systemd services running
#   api          — HTTP check on Jake API and code-server
#   continue     — Continue.dev config present
#   timer        — self-improvement timer active
# =============================================================================
set -euo pipefail

JAKECLAW_DIR="${JAKECLAW_DIR:-/JakeClaw}"
JAKE_DATA="${JAKE_DATA:-/Jake-data}"
VERBOSE=false
SUITE_FILTER=""

# ── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v) VERBOSE=true; shift ;;
    --suite)      SUITE_FILTER="$2"; shift 2 ;;
    *) echo "Usage: $0 [--verbose] [--suite <name>]" >&2; exit 1 ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────
GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[0;33m"; RESET="\033[0m"
BOLD="\033[1m"

PASS=0; FAIL=0; SKIP=0
declare -a FAILURES=()

pass() { echo -e "  ${GREEN}✔${RESET}  $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✘${RESET}  $1"; FAIL=$((FAIL+1)); FAILURES+=("$1"); }
skip() { echo -e "  ${YELLOW}–${RESET}  $1 (skipped)"; SKIP=$((SKIP+1)); }
suite() {
  [[ -n "${SUITE_FILTER}" ]] && [[ "${SUITE_FILTER}" != "$1" ]] && return 1
  echo -e "\n${BOLD}[$1]${RESET}"
  return 0
}

check_cmd() {
  local label="$1" cmd="$2"
  if eval "${cmd}" >/dev/null 2>&1; then
    if ${VERBOSE}; then
      pass "${label}: $(eval "${cmd}" 2>/dev/null | head -1)"
    else
      pass "${label}"
    fi
  else
    fail "${label}"
  fi
}

check_file() {
  [[ -e "$2" ]] && pass "$1: $2" || fail "$1: $2 not found"
}

check_svc() {
  local label="$1" svc="$2"
  if systemctl is-active --quiet "${svc}" 2>/dev/null; then
    pass "${label}: ${svc} active"
  elif ! systemctl list-unit-files "${svc}" >/dev/null 2>&1; then
    skip "${label}: ${svc} not installed"
  else
    fail "${label}: ${svc} not active"
  fi
}

check_http() {
  local label="$1" url="$2"
  if curl -sf --max-time 5 "${url}" -o /dev/null 2>/dev/null; then
    pass "${label}: ${url}"
  else
    fail "${label}: ${url} unreachable"
  fi
}

echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║         JakeClaw Deployment Test Suite                       ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo "  Run as: $(whoami) @ $(hostname)"
echo "  Date:   $(date)"

# ────────────────────────────────────────────────────────────────────────
if suite "user"; then
  # Check we're running as jake (or root for debug)
  EXPECTED_USER="${JAKE_USER:-jake}"
  [[ "$(whoami)" == "${EXPECTED_USER}" || "$(whoami)" == "root" ]] && \
    pass "Running as ${EXPECTED_USER}" || fail "Not running as ${EXPECTED_USER}"

  check_file "Jake home"   "${JAKE_HOME:-/home/jake}"
  check_cmd  "sudo access" "sudo -n true"
  check_file "JakeClaw repo" "${JAKECLAW_DIR}/.git"
fi

# ────────────────────────────────────────────────────────────────────────
if suite "mounts"; then
  if mountpoint -q "${JAKE_DATA}" 2>/dev/null; then
    pass "/Jake-data is mounted"
  else
    skip "/Jake-data not a separate mountpoint (single-disk setup)"
  fi
  check_file "Jake-data exists" "${JAKE_DATA}"
  [[ -w "${JAKE_DATA}" ]] && pass "${JAKE_DATA} is writable" || fail "${JAKE_DATA} not writable"
  check_file "Logs dir"   "${JAKE_DATA}/logs"
  check_file "Skills dir" "${JAKE_DATA}/skills"
fi

# ────────────────────────────────────────────────────────────────────────
if suite "versions"; then
  check_cmd "git"         "git --version"
  check_cmd "node"        "node --version"
  check_cmd "npm"         "npm --version"
  check_cmd "python3"     "python3 --version"
  check_cmd "pip3"        "pip3 --version"

  # Rust (user-level install)
  if command -v cargo >/dev/null 2>&1 || [[ -f "${HOME}/.cargo/bin/cargo" ]]; then
    pass "rust/cargo installed"
    ${VERBOSE} && (cargo --version 2>/dev/null || "${HOME}/.cargo/bin/cargo" --version) || true
  else
    skip "rust/cargo (not installed or not in PATH)"
  fi

  # claw
  if command -v claw >/dev/null 2>&1; then
    CLAW_VER=$(claw --version 2>/dev/null || echo "unknown")
    if echo "${CLAW_VER}" | grep -qi placeholder; then
      skip "claw: placeholder binary (real build needed — see install-claw-code.sh)"
    else
      pass "claw: ${CLAW_VER}"
    fi
  else
    fail "claw binary not found at /usr/local/bin/claw"
  fi

  # code-server
  if command -v code-server >/dev/null 2>&1; then
    pass "code-server: $(code-server --version 2>/dev/null | head -1)"
  else
    skip "code-server not installed"
  fi

  # claude (openclaw)
  if command -v claude >/dev/null 2>&1; then
    pass "openclaw (claude): $(claude --version 2>/dev/null | head -1)"
  else
    skip "openclaw (claude) not installed — check install-openclaw.sh"
  fi
fi

# ────────────────────────────────────────────────────────────────────────
if suite "services"; then
  check_svc "claw-code server"        "claw-code.service"
  check_svc "Jake API proxy"          "jake-api.service"
  check_svc "code-server"             "code-server.service"
  check_svc "self-improvement timer"  "jake-self-improve.timer"
fi

# ────────────────────────────────────────────────────────────────────────
if suite "api"; then
  check_http "Jake API /v1/models"    "http://localhost:8000/v1/models"
  check_http "code-server UI"         "http://localhost:8080"

  # Claw-code server (internal)
  if curl -sf --max-time 3 "http://localhost:8081/" -o /dev/null 2>/dev/null || \
     curl -sf --max-time 3 "http://localhost:8081/health" -o /dev/null 2>/dev/null; then
    pass "claw-code Axum server: localhost:8081"
  else
    skip "claw-code Axum server (localhost:8081 not responding — may need configuration)"
  fi
fi

# ────────────────────────────────────────────────────────────────────────
if suite "continue"; then
  CONTINUE_DIR="${HOME}/.continue"
  check_file ".continue dir"     "${CONTINUE_DIR}"
  check_file "continue config"   "${CONTINUE_DIR}/config.yaml"

  # Check symlink to Jake-data
  if [[ -L "${CONTINUE_DIR}" ]]; then
    pass ".continue symlinked to persistent volume"
  else
    skip ".continue is a regular directory (not symlinked — persistence not guaranteed on VM rebuild)"
  fi
fi

# ────────────────────────────────────────────────────────────────────────
if suite "timer"; then
  # Timer status
  TIMER_STATE=$(systemctl is-active jake-self-improve.timer 2>/dev/null || echo "inactive")
  if [[ "${TIMER_STATE}" == "active" ]]; then
    pass "self-improvement timer: ${TIMER_STATE}"
    ${VERBOSE} && systemctl status jake-self-improve.timer --no-pager 2>/dev/null | head -6 || true
  else
    fail "self-improvement timer: ${TIMER_STATE}"
  fi

  # Check log
  LOG_FILE="${JAKE_DATA}/logs/self-improvement.log"
  if [[ -f "${LOG_FILE}" ]]; then
    LAST_RUN=$(tail -1 "${LOG_FILE}" 2>/dev/null | cut -c1-20 || echo "unknown")
    pass "self-improvement log exists (last entry: ${LAST_RUN})"
  else
    skip "self-improvement log not yet created (timer hasn't fired)"
  fi
fi

# ────────────────────────────────────────────────────────────────────────
# Summary
echo ""
echo -e "${BOLD}══════════════════════ SUMMARY ══════════════════════${RESET}"
echo -e "  ${GREEN}PASSED: ${PASS}${RESET}   ${RED}FAILED: ${FAIL}${RESET}   ${YELLOW}SKIPPED: ${SKIP}${RESET}"

if [[ ${FAIL} -gt 0 ]]; then
  echo ""
  echo -e "${RED}${BOLD}Failed checks:${RESET}"
  for f in "${FAILURES[@]}"; do
    echo -e "  ${RED}✘${RESET} ${f}"
  done
  echo ""
  echo -e "${RED}Deployment has issues. Check /var/log/jake-bootstrap.log${RESET}"
  exit 1
else
  echo ""
  echo -e "${GREEN}${BOLD}All checks passed! Jake is ready.${RESET}"
  echo -e "  code-server: ${BOLD}http://\$(hostname -I | awk '{print \$1}'):8080${RESET}"
  echo -e "  Open Continue sidebar (Ctrl+L) → 'Hello Jake, survey the codebase'"
  exit 0
fi
