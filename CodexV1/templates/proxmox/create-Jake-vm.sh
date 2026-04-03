#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-Jake-vm.sh --name NAME --memory MB --cores N --ip IP_CIDR --storage STORAGE [options]

Required:
  --name NAME
  --memory MB
  --cores N
  --ip IP_CIDR
  --storage STORAGE

Optional:
  --template-id ID      Proxmox VM template ID (default: 9000)
  --bridge BRIDGE       Network bridge (default: vmbr0)
  --gateway IP          Gateway for static config
  --ci-user USER        Cloud-init user (default: jake)
  --ssh-key PATH        Public key path for cloud-init
  --vmid ID             Explicit VMID, else next free ID
  --force               Skip confirmation and existing-name guard
  --dry-run             Print qm commands only
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

run_or_print() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

NAME=""
MEMORY=""
CORES=""
IP_CIDR=""
STORAGE=""
TEMPLATE_ID="9000"
BRIDGE="vmbr0"
GATEWAY=""
CI_USER="jake"
SSH_KEY=""
VMID=""
FORCE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --cores) CORES="$2"; shift 2 ;;
    --ip) IP_CIDR="$2"; shift 2 ;;
    --storage) STORAGE="$2"; shift 2 ;;
    --template-id) TEMPLATE_ID="$2"; shift 2 ;;
    --bridge) BRIDGE="$2"; shift 2 ;;
    --gateway) GATEWAY="$2"; shift 2 ;;
    --ci-user) CI_USER="$2"; shift 2 ;;
    --ssh-key) SSH_KEY="$2"; shift 2 ;;
    --vmid) VMID="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "${NAME}" && -n "${MEMORY}" && -n "${CORES}" && -n "${IP_CIDR}" && -n "${STORAGE}" ]] || {
  usage
  exit 1
}

require_cmd qm
require_cmd pvesh

if [[ -z "${VMID}" ]]; then
  VMID="$(pvesh get /cluster/nextid)"
fi

if qm list | awk '{print $2}' | grep -Fxq "${NAME}"; then
  if [[ "${FORCE}" -ne 1 ]]; then
    echo "A VM named '${NAME}' already exists. Use --force to continue." >&2
    exit 1
  fi
fi

IPCONFIG="ip=${IP_CIDR}"
if [[ -n "${GATEWAY}" ]]; then
  IPCONFIG="${IPCONFIG},gw=${GATEWAY}"
fi

echo "About to create VM '${NAME}' (VMID ${VMID}) from template ${TEMPLATE_ID}."
if [[ "${FORCE}" -ne 1 && "${DRY_RUN}" -ne 1 ]]; then
  read -r -p "Proceed? [y/N] " reply
  if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
  fi
fi

run_or_print qm clone "${TEMPLATE_ID}" "${VMID}" --name "${NAME}" --full 1
run_or_print qm set "${VMID}" --memory "${MEMORY}" --cores "${CORES}"
run_or_print qm set "${VMID}" --net0 "virtio,bridge=${BRIDGE}"
run_or_print qm set "${VMID}" --ide2 "${STORAGE}:cloudinit"
run_or_print qm set "${VMID}" --scsi1 "${STORAGE}:32"
run_or_print qm set "${VMID}" --ipconfig0 "${IPCONFIG}"
run_or_print qm set "${VMID}" --ciuser "${CI_USER}"

if [[ -n "${SSH_KEY}" ]]; then
  run_or_print qm set "${VMID}" --sshkey "${SSH_KEY}"
fi

run_or_print qm start "${VMID}"
