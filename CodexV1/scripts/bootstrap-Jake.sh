#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "bootstrap-Jake.sh must run as root" >&2
  exit 1
fi

FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="/var/log/jake-bootstrap.log"

exec > >(tee -a "${LOG_FILE}") 2>&1

ENV_FILE="${REPO_DIR}/config/.env"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

export DEBIAN_FRONTEND=noninteractive
export JAKE_USER="${JAKE_USER:-jake}"
export JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
export JAKE_DATA_DIR="${JAKE_DATA_DIR:-/Jake-data}"
export JAKE_REPO_DIR="${JAKE_REPO_DIR:-${REPO_DIR}}"

mkdir -p "${JAKE_DATA_DIR}"/{logs,config,skills,workspace}
mkdir -p "${JAKE_HOME}"
chown -R "${JAKE_USER}:${JAKE_USER}" "${JAKE_DATA_DIR}" || true

run_step() {
  local script_name="$1"
  echo "=== Running ${script_name} ==="
  "${SCRIPT_DIR}/${script_name}" --force="${FORCE}"
}

run_step "install-dev-env.sh"
run_step "install-code-server.sh"
run_step "install-continue-dev.sh"
run_step "install-openclaw.sh"
run_step "install-claw-code.sh"
run_step "setup-jake-api.sh"
run_step "expose-claw-tools.sh"
run_step "setup-self-improvement.sh"

echo "Jake bootstrap completed."
