# Packer (Optional)

This file describes how to use the optional Packer template `packer/proxmox-ubuntu-jake.pkr.hcl`.

Steps (high-level):
1. Install Packer (1.7+).
2. Configure Proxmox builder plugin or use a qemu builder and upload the resulting image to Proxmox.
3. Run `packer validate packer/proxmox-ubuntu-jake.pkr.hcl` then `packer build packer/proxmox-ubuntu-jkr.pkr.hcl` (adapt names).

Notes:
- Do NOT include secrets in the build. Use variables and pass credentials at runtime.
- This is an advanced option and requires a working Proxmox API or appropriate builder plugin.
