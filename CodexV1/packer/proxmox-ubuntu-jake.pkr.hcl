packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type        = string
  description = "REQUIRED INPUT: Proxmox API endpoint."
}

variable "proxmox_node" {
  type        = string
  description = "REQUIRED INPUT: Proxmox node name."
}

variable "proxmox_storage" {
  type        = string
  description = "REQUIRED INPUT: Proxmox storage target."
}

variable "proxmox_token_id" {
  type        = string
  default     = env("PROXMOX_TOKEN_ID")
  description = "REQUIRED INPUT: API token ID."
}

variable "proxmox_token_secret" {
  type        = string
  default     = env("PROXMOX_TOKEN_SECRET")
  description = "REQUIRED INPUT: API token secret."
  sensitive   = true
}

variable "ssh_username" {
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_file" {
  type        = string
  description = "REQUIRED INPUT: SSH private key used during image build."
}

source "proxmox-iso" "ubuntu_jake" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_token_id
  token                    = var.proxmox_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_name     = "ubuntu-2404-jake-template"
  template_name = "ubuntu-2404-jake-template"
  cpu_type    = "host"
  cores       = 4
  memory      = 4096
  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size    = "32G"
    format       = "raw"
    storage_pool = var.proxmox_storage
    type         = "virtio"
  }

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }

  iso_file         = "local:iso/ubuntu-24.04-live-server-amd64.iso"
  unmount_iso      = true
  ssh_username     = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
}

build {
  name    = "jake-proxmox-template"
  sources = ["source.proxmox-iso.ubuntu_jake"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y cloud-init qemu-guest-agent git curl jq",
      "sudo systemctl enable qemu-guest-agent"
    ]
  }
}
