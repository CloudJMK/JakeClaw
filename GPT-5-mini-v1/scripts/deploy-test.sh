#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check() {
  desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[PASS] $desc"
    PASS=$((PASS+1))
  else
    echo "[FAIL] $desc"
    FAIL=$((FAIL+1))
  fi
}

# 1. User & mount
check "jake user exists" id jake
check "/Jake-data mounted" test -d /Jake-data || true

# 2. Dev tools
check "git available" git --version
check "python3 available" python3 --version
check "node available" node --version || true
check "cargo available" cargo --version || true

# 3. Claw & OpenClaw (scaffold checks; commands may be absent in a dry run)
check "claw present" command -v claw
check "openclaw present" command -v openclaw || true

# 4. Services (non-fatal checks)
check "code-server service" systemctl is-active --quiet "code-server@jake" || true
check "jake-api (litellm) listening on 8000" curl -sS http://localhost:8000/v1/models >/dev/null || true

# Summary
echo "Summary: PASS=$PASS FAIL=$FAIL"
if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
