# =============================================================================
# proxmox-ubuntu-jake.pkr.hcl — Packer template for pre-baked JakeClaw image
#
# Builds a Proxmox VM template with Jake fully installed so deployments
# are instant (no cloud-init bootstrap wait time).
#
# Prerequisites:
#   - Packer 1.9+ installed: https://developer.hashicorp.com/packer/install
#   - Proxmox plugin: packer plugins install github.com/hashicorp/proxmox
#   - Proxmox API token with VM create/modify permissions
#
# USER INPUT REQUIRED (set via environment or var file):
#   PKR_VAR_proxmox_url        — e.g. https://192.168.1.10:8006/api2/json
#   PKR_VAR_proxmox_token_id   — e.g. root@pam!packer
#   PKR_VAR_proxmox_token_secret
#   PKR_VAR_ssh_public_key     — paste your SSH public key
#   PKR_VAR_anthropic_api_key  — Anthropic API key (baked as env var, NOT stored in image)
#
# Usage:
#   packer validate proxmox-ubuntu-jake.pkr.hcl
#   packer build   proxmox-ubuntu-jake.pkr.hcl
#
# WARNING: Do NOT bake API keys or passwords into the image itself.
#          Keys are injected at first-VM-start via cloud-init or Doppler.
#          Only configuration (not secrets) is pre-installed here.
# =============================================================================

packer {
  required_version = ">= 1.9.0"
  required_plugins {
    proxmox = {
      version = ">= 1.1.7"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ─── Variables ────────────────────────────────────────────────────────────────

variable "proxmox_url" {
  type    = string
  default = "https://192.168.1.10:8006/api2/json"
  # USER INPUT REQUIRED: your Proxmox API URL
}

variable "proxmox_node" {
  type    = string
  default = "pve"
  # USER INPUT OPTIONAL: Proxmox node name
}

variable "proxmox_token_id" {
  type      = string
  sensitive = false
  # USER INPUT REQUIRED: e.g. root@pam!packer
}

variable "proxmox_token_secret" {
  type      = string
  sensitive = true
  # USER INPUT REQUIRED: Proxmox API token secret
}

variable "proxmox_storage" {
  type    = string
  default = "local-lvm"
  # USER INPUT OPTIONAL
}

variable "ubuntu_iso_url" {
  type    = string
  default = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  # Ubuntu 24.04 LTS cloud image
}

variable "ubuntu_iso_checksum" {
  type    = string
  default = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
  # Checksum file URL — packer will fetch and verify
}

variable "template_vm_id" {
  type    = number
  default = 9001
  # USER INPUT OPTIONAL: VMID for the new template
}

variable "ssh_public_key" {
  type      = string
  sensitive = false
  # USER INPUT REQUIRED: your SSH public key for image access during build
}

variable "jake_password" {
  type      = string
  sensitive = true
  default   = "jake-build-tmp"
  # Temporary build password — jake user will use SSH key in production
}

variable "jakeclaw_repo" {
  type    = string
  default = "https://github.com/CloudJMK/JakeClaw.git"
  # USER INPUT OPTIONAL: your fork URL
}

# ─── Source block ─────────────────────────────────────────────────────────────

source "proxmox-iso" "jake-ubuntu" {
  proxmox_url              = var.proxmox_url
  node                     = var.proxmox_node
  token                    = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure_skip_tls_verify = true   # USER INPUT: set false if you have valid TLS

  vm_id   = var.template_vm_id
  vm_name = "jake-template-ubuntu2404"

  iso_url          = var.ubuntu_iso_url
  iso_checksum     = var.ubuntu_iso_checksum
  iso_storage_pool = "local"
  unmount_iso      = true

  os      = "l26"
  cpu_type = "x86-64-v2-AES"
  cores   = 4
  sockets = 1
  memory  = 8192
  balloon = 0

  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size         = "40G"
    storage_pool      = var.proxmox_storage
    type              = "scsi"
    discard           = true
    ssd               = true
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Additional data disk for /Jake-data
  disks {
    disk_size    = "20G"
    storage_pool = var.proxmox_storage
    type         = "scsi"
    discard      = true
  }

  cloud_init              = true
  cloud_init_storage_pool = var.proxmox_storage

  # User-data injected for build only
  additional_iso_files {
    cd_content = {
      "/meta-data" = ""
      "/user-data" = templatefile("${path.root}/../templates/cloud-init/user-data.yaml", {
        SSH_PUBLIC_KEY = var.ssh_public_key
        JAKE_PASSWORD  = bcrypt(var.jake_password)
        JAKECLAW_REPO  = var.jakeclaw_repo
        JAKE_DATA_DISK = "/dev/sdb"
      })
    }
    cd_label         = "cidata"
    iso_storage_pool = "local"
  }

  boot_command = [
    "<enter>"
  ]

  boot_wait = "5s"

  ssh_username = "jake"
  ssh_private_key_file = "~/.ssh/id_ed25519"
  ssh_timeout  = "30m"

  qemu_agent = true
}

# ─── Build block ──────────────────────────────────────────────────────────────

build {
  name    = "jake-ubuntu-template"
  sources = ["source.proxmox-iso.jake-ubuntu"]

  # Wait for cloud-init to finish
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait",
      "echo 'cloud-init done'"
    ]
  }

  # Verify bootstrap completed
  provisioner "shell" {
    inline = [
      "test -f /var/log/jake-bootstrap.log || { echo 'Bootstrap log missing'; exit 1; }",
      "grep -q 'Bootstrap COMPLETE' /var/log/jake-bootstrap.log || { echo 'Bootstrap did not complete'; exit 1; }",
      "echo 'Bootstrap verified OK'"
    ]
  }

  # Run deployment tests
  provisioner "shell" {
    inline = [
      "bash /JakeClaw/scripts/deploy-test.sh --suite versions",
      "bash /JakeClaw/scripts/deploy-test.sh --suite services"
    ]
  }

  # Clean up before templating
  # IMPORTANT: remove build-specific state; secrets are NOT baked in
  provisioner "shell" {
    inline = [
      # Remove cloud-init state so it re-runs on first clone boot
      "sudo cloud-init clean --logs",
      # Clear bash history
      "history -c",
      "cat /dev/null > ~/.bash_history",
      # Remove any temp build credentials
      # NOTE: ANTHROPIC_API_KEY is NOT stored in image
      # It must be set via cloud-init or Doppler at first boot
      "sudo sed -i '/ANTHROPIC_API_KEY/d' /etc/environment 2>/dev/null || true",
      "echo 'Image cleanup complete'"
    ]
  }

  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}
