#!/usr/bin/env bash
# create-Jake-vm.sh — Create and configure the Jake VM on Proxmox
#
# Run this script ON YOUR PROXMOX HOST (not inside an existing VM).
# It clones a cloud-init Ubuntu template, configures hardware, uploads
# cloud-init snippets, and starts the VM.
#
# Usage:
#   bash create-Jake-vm.sh [OPTIONS]
#
# Options:
#   --name       <name>     VM name (default: jake)
#   --vmid       <id>       VM ID (default: auto-select next available)
#   --memory     <mb>       RAM in MB (default: 4096)
#   --cores      <n>        CPU cores (default: 2)
#   --storage    <pool>     Proxmox storage pool (default: $PROXMOX_STORAGE or local-lvm)
#   --template   <id>       Template VM ID (default: $PROXMOX_TEMPLATE_ID)
#   --disk-size  <size>     Root disk size, e.g. 32G (default: 32G)
#   --data-disk  <size>     /Jake-data disk size, e.g. 20G (default: 20G)
#   --ip         <ip/gw>    Static IP, e.g. 192.168.1.50/24,gw=192.168.1.1
#                           Omit for DHCP.
#   --snippets   <dir>      Proxmox snippets directory (default: /var/lib/vz/snippets)
#   --dry-run               Print commands without executing them
#   --force                 Destroy existing VM with same ID before creating

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
VM_NAME="jake"
VM_ID=""
VM_MEMORY=4096
VM_CORES=2
VM_IP="dhcp"
DRY_RUN=false
FORCE=false

# Load .env from two directories up (relative to script location, when repo is on Proxmox host)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi  # shellcheck source=/dev/null

PROXMOX_STORAGE="${PROXMOX_STORAGE:-local-lvm}"
PROXMOX_TEMPLATE_ID="${PROXMOX_TEMPLATE_ID:-9000}"
PROXMOX_SNIPPETS_DIR="${PROXMOX_SNIPPETS_DIR:-/var/lib/vz/snippets}"
JAKECLAW_REPO="${JAKECLAW_REPO:-https://github.com/CloudJMK/JakeClaw}"
JAKE_DATA_DISK_DEVICE="${JAKE_DATA_DISK_DEVICE:-/dev/sdb}"

DISK_SIZE="32G"
DATA_DISK_SIZE="20G"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)       VM_NAME="$2";             shift 2 ;;
    --vmid)       VM_ID="$2";               shift 2 ;;
    --memory)     VM_MEMORY="$2";           shift 2 ;;
    --cores)      VM_CORES="$2";            shift 2 ;;
    --storage)    PROXMOX_STORAGE="$2";     shift 2 ;;
    --template)   PROXMOX_TEMPLATE_ID="$2"; shift 2 ;;
    --disk-size)  DISK_SIZE="$2";           shift 2 ;;
    --data-disk)  DATA_DISK_SIZE="$2";      shift 2 ;;
    --ip)         VM_IP="$2";               shift 2 ;;
    --snippets)   PROXMOX_SNIPPETS_DIR="$2";shift 2 ;;
    --dry-run)    DRY_RUN=true;             shift ;;
    --force)      FORCE=true;               shift ;;
    --help|-h)
      sed -n '/^# Usage/,/^[^#]/p' "${BASH_SOURCE[0]}" | head -n -1 | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }
die() { err "$*"; exit 1; }

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

confirm() {
  local msg="$1"
  read -r -p "${msg} [y/N] " answer
  [[ "${answer,,}" == "y" ]]
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
command -v qm &>/dev/null || die "'qm' not found — run this script on your Proxmox host"
[[ -n "$PROXMOX_TEMPLATE_ID" ]] || die "PROXMOX_TEMPLATE_ID not set (set it in ../.env or pass --template)"

# ---------------------------------------------------------------------------
# Select VM ID
# ---------------------------------------------------------------------------
if [[ -z "$VM_ID" ]]; then
  VM_ID=$(pvesh get /cluster/nextid 2>/dev/null || echo "")
  [[ -n "$VM_ID" ]] || die "Could not auto-select VM ID. Pass --vmid <id>"
  log "Auto-selected VM ID: ${VM_ID}"
fi

# ---------------------------------------------------------------------------
# Handle existing VM
# ---------------------------------------------------------------------------
if qm status "$VM_ID" &>/dev/null; then
  if [[ "$FORCE" == "true" ]]; then
    log "Destroying existing VM ${VM_ID} (--force)"
    run qm stop "$VM_ID" --skiplock 1 2>/dev/null || true
    run qm destroy "$VM_ID" --purge 1
  else
    die "VM ${VM_ID} already exists. Use --force to replace it, or pass a different --vmid"
  fi
fi

# ---------------------------------------------------------------------------
# Upload cloud-init snippets
# ---------------------------------------------------------------------------
log "Uploading cloud-init snippets to ${PROXMOX_SNIPPETS_DIR}"
mkdir -p "$PROXMOX_SNIPPETS_DIR"

TEMPLATES_DIR="${SCRIPT_DIR}/../cloud-init"

# Substitute placeholders in user-data before uploading
USERDATA_SRC="${TEMPLATES_DIR}/user-data.yaml"
USERDATA_DST="${PROXMOX_SNIPPETS_DIR}/jake-user-data.yaml"

if [[ -f "$USERDATA_SRC" ]]; then
  sed \
    -e "s|<<REPLACE_JAKECLAW_REPO>>|${JAKECLAW_REPO}|g" \
    -e "s|<<REPLACE_DATA_DISK>>|${JAKE_DATA_DISK_DEVICE}|g" \
    -e "s|<<REPLACE_VM_IP>>|${VM_IP}|g" \
    "$USERDATA_SRC" > "$USERDATA_DST"
  log "user-data.yaml substituted and written to ${USERDATA_DST}"
  log "ACTION REQUIRED: Edit ${USERDATA_DST} to fill in SSH_PUBLIC_KEY and HASHED_PASSWORD"
else
  die "user-data.yaml not found at ${USERDATA_SRC}"
fi

NETWORK_SRC="${TEMPLATES_DIR}/network-config.yaml"
if [[ -f "$NETWORK_SRC" ]]; then
  cp "$NETWORK_SRC" "${PROXMOX_SNIPPETS_DIR}/jake-network-config.yaml"
fi

# ---------------------------------------------------------------------------
# Clone template
# ---------------------------------------------------------------------------
log "Cloning template ${PROXMOX_TEMPLATE_ID} → VM ${VM_ID} (${VM_NAME})"
run qm clone "$PROXMOX_TEMPLATE_ID" "$VM_ID" \
  --name "$VM_NAME" \
  --full \
  --storage "$PROXMOX_STORAGE"

# ---------------------------------------------------------------------------
# Configure hardware
# ---------------------------------------------------------------------------
log "Configuring VM hardware"
run qm set "$VM_ID" \
  --memory "$VM_MEMORY" \
  --balloon 0 \
  --cores "$VM_CORES" \
  --sockets 1 \
  --cpu cputype=host \
  --agent enabled=1

# Resize root disk
log "Resizing root disk to ${DISK_SIZE}"
run qm resize "$VM_ID" scsi0 "${DISK_SIZE}"

# Add /Jake-data disk (scsi1)
log "Adding ${DATA_DISK_SIZE} /Jake-data disk"
run qm set "$VM_ID" \
  --scsi1 "${PROXMOX_STORAGE}:${DATA_DISK_SIZE},discard=on"

# ---------------------------------------------------------------------------
# Apply cloud-init config
# ---------------------------------------------------------------------------
log "Applying cloud-init configuration"
LOCAL_SNIPPETS="local:snippets"

if [[ "$VM_IP" == "dhcp" ]]; then
  IPCONFIG="ip=dhcp"
else
  IPCONFIG="ip=${VM_IP}"
fi

run qm set "$VM_ID" \
  --ipconfig0 "$IPCONFIG" \
  --cicustom "user=${LOCAL_SNIPPETS}/jake-user-data.yaml,network=${LOCAL_SNIPPETS}/jake-network-config.yaml"

# ---------------------------------------------------------------------------
# Start VM
# ---------------------------------------------------------------------------
log "Starting VM ${VM_ID}"
run qm start "$VM_ID"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "======================================================"
echo " Jake VM created successfully!"
echo ""
echo " VM ID  : ${VM_ID}"
echo " Name   : ${VM_NAME}"
echo " Memory : ${VM_MEMORY} MB"
echo " Cores  : ${VM_CORES}"
echo " IP     : ${VM_IP}"
echo ""
echo " Next steps:"
echo "   1. Wait ~5 minutes for cloud-init to finish"
echo "   2. Find the VM's IP: qm agent ${VM_ID} network-get-interfaces"
echo "   3. SSH in: ssh jake@<VM-IP>"
echo "   4. Verify: bash /JakeClaw/JakeClaw-V2/scripts/deploy-test.sh"
echo ""
echo " IMPORTANT: Review and complete the cloud-init file before production use:"
echo "   ${USERDATA_DST}"
echo "======================================================"
