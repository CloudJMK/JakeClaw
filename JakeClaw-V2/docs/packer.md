# Packer — Baking a Reusable Jake Image

The `packer/` directory contains a HashiCorp Packer configuration for building
a pre-provisioned Proxmox VM template with Jake fully installed.

Use this if you want to:
- Spin up new Jake VMs in under a minute (no cloud-init wait)
- Version-control your baked images
- Run Jake on multiple machines from the same base

## Prerequisites

- Packer 1.9+ installed on your local machine or Proxmox host
- A running Proxmox host with API access
- The `proxmox` Packer plugin

## How It Works

1. Packer clones the Ubuntu 24.04 cloud-init template
2. SSHs into the VM and runs `bootstrap-Jake.sh`
3. Shuts down the VM and converts it to a Proxmox template
4. Future VMs clone from this template — no install wait

## Quick Build

```bash
cd JakeClaw-V2/packer

# Initialize plugins
packer init .

# Build the image (replace values as needed)
packer build \
  -var "proxmox_url=https://<PROXMOX-IP>:8006/api2/json" \
  -var "proxmox_username=root@pam" \
  -var "proxmox_password=<PASSWORD>" \
  -var "template_name=jake-v2-$(date +%Y%m%d)" \
  proxmox-ubuntu-jake.pkr.hcl
```

## Variables

All `packer build -var` values can alternatively be set in a `.auto.pkrvars.hcl`
file (not committed to git) or via the `PKR_VAR_` environment variable prefix.

| Variable | Description |
|---|---|
| `proxmox_url` | Proxmox API endpoint |
| `proxmox_username` | Proxmox API user |
| `proxmox_password` | Proxmox API password |
| `proxmox_node` | Proxmox node name (default: pve) |
| `template_name` | Name for the resulting template |
| `source_template_id` | Ubuntu 24.04 cloud-init template ID to clone from |

## After the Build

Clone the baked template for new Jake VMs:

```bash
qm clone <BAKED-TEMPLATE-ID> <NEW-VM-ID> --name jake-new --full
qm start <NEW-VM-ID>
```

Jake will start in ~30 seconds with no bootstrap wait.
