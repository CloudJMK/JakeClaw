# Packer

## Purpose

The optional Packer template can pre-bake a Proxmox-ready Ubuntu image with the JakeClaw bootstrap prerequisites installed.

## Before you run it

- Supply your Proxmox endpoint, token ID, and token secret through environment variables or a `*.pkrvars.hcl` file that is not committed.
- Provide a valid SSH public key and private key path for the build VM.
- Review every placeholder in `packer/proxmox-ubuntu-jake.pkr.hcl`.

## Validate

```bash
packer validate packer/proxmox-ubuntu-jake.pkr.hcl
```

## Build

```bash
packer build \
  -var "proxmox_url=https://proxmox.example.com:8006/api2/json" \
  -var "proxmox_node=pve01" \
  -var "proxmox_storage=local-lvm" \
  packer/proxmox-ubuntu-jake.pkr.hcl
```

## Important

Do not bake API keys, `.env` files, or long-lived secrets into the image.
