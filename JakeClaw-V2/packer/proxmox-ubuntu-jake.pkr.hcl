packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "proxmox_url"           { type = string }
variable "proxmox_username"      { type = string }
variable "proxmox_password"      { type = string; sensitive = true }
variable "proxmox_node"          { type = string; default = "pve" }
variable "source_template_id"    { type = number; default = 9000 }
variable "template_name"         { type = string; default = "jake-v2" }
variable "template_description"  { type = string; default = "JakeClaw-V2 baked image" }
variable "vm_id"                 { type = number; default = 9100 }
variable "memory_mb"             { type = number; default = 4096 }
variable "cores"                 { type = number; default = 2 }
variable "disk_size"             { type = string; default = "32G" }
variable "storage_pool"          { type = string; default = "local-lvm" }
variable "ssh_username"          { type = string; default = "jake" }
variable "ssh_private_key_file"  { type = string; default = "~/.ssh/id_ed25519" }

# ---------------------------------------------------------------------------
# Source: clone from existing Ubuntu 24.04 cloud-init template
# ---------------------------------------------------------------------------
source "proxmox-clone" "jake" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  clone_vm_id   = var.source_template_id
  vm_id         = var.vm_id
  vm_name       = var.template_name
  full_clone    = true

  memory  = var.memory_mb
  cores   = var.cores
  sockets = 1
  cpu_type = "host"

  scsi_controller = "virtio-scsi-pci"
  disks {
    type         = "scsi"
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
    discard      = true
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  communicator     = "ssh"
  ssh_username     = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout      = "30m"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
build {
  name    = "jake-v2"
  sources = ["source.proxmox-clone.jake"]

  # Wait for cloud-init to complete (handles initial package setup)
  provisioner "shell" {
    inline = ["cloud-init status --wait || true"]
  }

  # Clone JakeClaw repo
  provisioner "shell" {
    inline = [
      "if [ ! -d /JakeClaw/.git ]; then git clone https://github.com/CloudJMK/JakeClaw /JakeClaw; fi",
      "chown -R jake:jake /JakeClaw"
    ]
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  # Run bootstrap
  provisioner "shell" {
    script          = "../scripts/bootstrap-Jake.sh"
    execute_command = "sudo bash {{ .Path }}"
    timeout         = "20m"
  }

  # Convert to template
  post-processor "shell-local" {
    inline = [
      "echo 'Build complete — template ID: ${var.vm_id}'",
      "echo 'Convert to template with: qm template ${var.vm_id}'"
    ]
  }
}
