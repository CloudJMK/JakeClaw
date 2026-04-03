#!/usr/bin/env bash
# =============================================================================
# create-Jake-vm.sh — One-command JakeClaw VM deployment on Proxmox
#
# Usage:
#   bash create-Jake-vm.sh [OPTIONS]
#
# Options:
#   --name       NAME       VM name / hostname  (default: jake)
#   --memory     MB         RAM in MB           (default: 8192)
#   --cores      N          CPU cores           (default: 4)
#   --storage    POOL       Proxmox storage     (default: local-lvm)
#   --ip         IP/CIDR    Static IP           (default: DHCP)
#   --vmid       ID         Proxmox VM ID       (default: auto-select next free)
#   --template   ID         Template VM ID      (default: from .env or 9000)
#   --disk-size  GB         Root disk size      (default: 40)
#   --data-disk  GB         /Jake-data disk     (default: 20)
#   --snippets   PATH       Proxmox snippets path (default: local:snippets)
#   --dry-run               Print qm commands without executing
#   --force                 Skip confirmation prompts; overwrite existing VM
#   --help                  Show this help
#
# Prerequisites:
#   - Run on the Proxmox host as root, or via SSH with pvesh/qm in PATH
#   - Ubuntu 24.04 cloud-init template already created (see docs/deployment-guide.md)
#   - config/.env filled in (especially PROXMOX_TEMPLATE_ID, SSH key in user-data.yaml)
#
# USER INPUT REQUIRED:
#   1. Edit templates/cloud-init/user-data.yaml — replace {{SSH_PUBLIC_KEY}}
#   2. Fill config/.env with PROXMOX_TEMPLATE_ID, PROXMOX_STORAGE, etc.
#   3. If not running on the Proxmox host itself, set PROXMOX_HOST in .env
#      and ensure SSH key access.
# =============================================================================
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────
VM_NAME="jake"
MEMORY=8192
CORES=4
STORAGE="local-lvm"
DISK_SIZE=40
DATA_DISK_SIZE=20
TEMPLATE_ID=""
VMID=""
IP="dhcp"
SNIPPETS_STORAGE="local"
DRY_RUN=false
FORCE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Load .env ──────────────────────────────────────────────────────────────
ENV_FILE="${REPO_ROOT}/config/.env"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
fi

TEMPLATE_ID="${PROXMOX_TEMPLATE_ID:-9000}"
STORAGE="${PROXMOX_STORAGE:-${STORAGE}}"

# ── Helpers ───────────────────────────────────────────────────────────────
log()  { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [create-Jake-vm] $*"; }
err()  { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [create-Jake-vm] ERROR: $*" >&2; }
die()  { err "$*"; exit 1; }

run() {
  if ${DRY_RUN}; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

usage() {
  grep '^#' "$0" | grep -E '^\s*#\s+(Usage|Options|--|\s)' | sed 's/^# //'
  exit 0
}

confirm() {
  local msg="$1"
  if ${FORCE} || ${DRY_RUN}; then return 0; fi
  echo ""
  echo "  ┌─────────────────────────────────────────────────────────┐"
  echo "  │  ${msg}"
  echo "  └─────────────────────────────────────────────────────────┘"
  echo ""
  read -r -p "  Proceed? [yes/no]: " answer
  [[ "${answer}" == "yes" ]] || { log "Aborted by user."; exit 1; }
}

# ── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)       VM_NAME="$2";       shift 2 ;;
    --memory)     MEMORY="$2";        shift 2 ;;
    --cores)      CORES="$2";         shift 2 ;;
    --storage)    STORAGE="$2";       shift 2 ;;
    --ip)         IP="$2";            shift 2 ;;
    --vmid)       VMID="$2";          shift 2 ;;
    --template)   TEMPLATE_ID="$2";   shift 2 ;;
    --disk-size)  DISK_SIZE="$2";     shift 2 ;;
    --data-disk)  DATA_DISK_SIZE="$2"; shift 2 ;;
    --snippets)   SNIPPETS_STORAGE="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true;       shift ;;
    --force)      FORCE=true;         shift ;;
    --help|-h)    usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# ── Validate prerequisites ────────────────────────────────────────────────
command -v qm >/dev/null 2>&1 || \
  die "qm not found. Run this script on the Proxmox host or ensure qm is in PATH."

[[ -n "${TEMPLATE_ID}" ]] || \
  die "PROXMOX_TEMPLATE_ID not set. Set it in config/.env or pass --template <ID>."

# ── Select next free VMID if not specified ────────────────────────────────
if [[ -z "${VMID}" ]]; then
  VMID=$(pvesh get /cluster/nextid 2>/dev/null || echo "")
  [[ -n "${VMID}" ]] || die "Could not determine next free VMID. Pass --vmid manually."
fi

log "Planning VM: name=${VM_NAME} id=${VMID} template=${TEMPLATE_ID} mem=${MEMORY}MB cores=${CORES} storage=${STORAGE}"

# ── Check if VM already exists ────────────────────────────────────────────
if qm status "${VMID}" >/dev/null 2>&1; then
  if ${FORCE}; then
    log "VM ${VMID} exists — --force specified, destroying it..."
    run qm stop "${VMID}" 2>/dev/null || true
    run qm destroy "${VMID}" --purge
  else
    die "VM ${VMID} already exists. Use --force to overwrite, or pick a different --vmid."
  fi
fi

# ── Upload cloud-init snippets ─────────────────────────────────────────────
SNIPPETS_DIR="/var/lib/vz/snippets"
CLOUD_INIT_SRC="${REPO_ROOT}/templates/cloud-init"
USER_DATA_DEST="${SNIPPETS_DIR}/jake-user-data-${VM_NAME}.yaml"
NETWORK_DEST="${SNIPPETS_DIR}/jake-network-${VM_NAME}.yaml"

log "Uploading cloud-init snippets to ${SNIPPETS_DIR}/"
run mkdir -p "${SNIPPETS_DIR}"
run cp "${CLOUD_INIT_SRC}/user-data.yaml"      "${USER_DATA_DEST}"
run cp "${CLOUD_INIT_SRC}/network-config.yaml" "${NETWORK_DEST}"

# ── Clone template ────────────────────────────────────────────────────────
confirm "About to clone VM template ${TEMPLATE_ID} → new VM '${VM_NAME}' (ID: ${VMID})"

log "Cloning template ${TEMPLATE_ID} → VMID ${VMID}..."
run qm clone "${TEMPLATE_ID}" "${VMID}" \
  --name "${VM_NAME}" \
  --full \
  --storage "${STORAGE}"

# ── Configure hardware ────────────────────────────────────────────────────
log "Configuring VM hardware..."
run qm set "${VMID}" \
  --memory "${MEMORY}" \
  --cores "${CORES}" \
  --sockets 1 \
  --cpu cputype=x86-64-v2-AES \
  --balloon 0

# ── Resize root disk ──────────────────────────────────────────────────────
log "Resizing root disk to ${DISK_SIZE}G..."
run qm resize "${VMID}" scsi0 "${DISK_SIZE}G"

# ── Add /Jake-data disk ────────────────────────────────────────────────────
log "Adding /Jake-data disk (${DATA_DISK_SIZE}G)..."
run qm set "${VMID}" --scsi1 "${STORAGE}:${DATA_DISK_SIZE},discard=on"

# ── Apply cloud-init ──────────────────────────────────────────────────────
log "Applying cloud-init configuration..."
if [[ "${IP}" == "dhcp" ]]; then
  NET_CONFIG="ip=dhcp"
else
  NET_CONFIG="ip=${IP},gw=$(echo "${IP}" | cut -d. -f1-3).1"
fi

run qm set "${VMID}" \
  --ipconfig0 "${NET_CONFIG}" \
  --cicustom "user=${SNIPPETS_STORAGE}:snippets/jake-user-data-${VM_NAME}.yaml,network=${SNIPPETS_STORAGE}:snippets/jake-network-${VM_NAME}.yaml" \
  --agent enabled=1,fstrim_cloned_disks=1

# ── Start VM ──────────────────────────────────────────────────────────────
confirm "VM '${VM_NAME}' (ID: ${VMID}) is ready. Start it now?"
log "Starting VM ${VMID}..."
run qm start "${VMID}"

# ── Done ──────────────────────────────────────────────────────────────────
echo ""
echo "  ╔════════════════════════════════════════════════════════════╗"
echo "  ║  JakeClaw VM '${VM_NAME}' (ID: ${VMID}) is booting!       "
echo "  ║                                                            "
echo "  ║  First boot will run cloud-init + bootstrap (~5 min).     "
echo "  ║                                                            "
echo "  ║  After boot:                                               "
echo "  ║    SSH:       ssh jake@<VM_IP>                             "
echo "  ║    IDE:       http://<VM_IP>:8080                          "
echo "  ║    API:       http://<VM_IP>:8000/v1/models                "
echo "  ║                                                            "
echo "  ║  Watch boot log:                                           "
echo "  ║    ssh jake@<VM_IP> tail -f /var/log/jake-bootstrap.log   "
echo "  ║                                                            "
echo "  ║  Verify deployment:                                        "
echo "  ║    ssh jake@<VM_IP> bash /JakeClaw/scripts/deploy-test.sh "
echo "  ╚════════════════════════════════════════════════════════════╝"
echo ""
