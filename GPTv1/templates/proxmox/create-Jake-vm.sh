#!/usr/bin/env bash
set -euo pipefail

# create-Jake-vm.sh
# Usage: create-Jake-vm.sh --name <name> --memory <MB> --cores <N> [--ip <IP>] [--storage <pool>] [--force]

# NOTE: This script is a scaffold. It assumes `qm` (Proxmox CLI) and local Proxmox access.
# Replace or adapt to your environment and credential method (pvesh/API tokens) before running.

usage(){
  cat <<EOF
Usage: $0 --name NAME [--memory MB] [--cores N] [--ip IP/CIDR] [--storage POOL] [--force]
EOF
}

# Defaults
NAME=""
MEMORY=8192
CORES=4
IP=""
STORAGE=${STORAGE:-local-zfs}
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2;;
    --memory) MEMORY="$2"; shift 2;;
    --cores) CORES="$2"; shift 2;;
    --ip) IP="$2"; shift 2;;
    --storage) STORAGE="$2"; shift 2;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

if [ -z "$NAME" ]; then
  echo "--name is required"; usage; exit 1
fi

# Confirm
if [ "$FORCE" -ne 1 ]; then
  echo "About to create VM: name=$NAME memory=${MEMORY}MB cores=$CORES storage=$STORAGE"
  read -p "Proceed? [y/N] " ans
  if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
    echo "Aborted by user"
    exit 1
  fi
fi

# This scaffold expects a pre-created cloud-init template named 'ubuntu-24-cloud-init-template'.
TEMPLATE="ubuntu-24-cloud-init-template"

# Check template exists (example):
if ! qm list | grep -q "$TEMPLATE"; then
  echo "Template $TEMPLATE not found in qm list. Create or change TEMPLATE in script."; exit 1
fi

# Clone template (placeholder commands — adapt as needed)
NEW_VMID=$(pvesh get /cluster/nextid)
qm clone "$TEMPLATE" $NEW_VMID --name "$NAME" --storage "$STORAGE"
qm set $NEW_VMID --memory $MEMORY --cores $CORES

# Optionally configure cloud-init IP (requires cloud-init support in template)
if [ -n "$IP" ]; then
  # This is a placeholder; actual cloud-init user-data injection method may differ
  echo "Setting static IP to $IP (placeholder — adapt for your template)"
fi

qm start $NEW_VMID

echo "VM $NAME created as VMID $NEW_VMID. Wait for boot and use cloud-init to provision the instance."
