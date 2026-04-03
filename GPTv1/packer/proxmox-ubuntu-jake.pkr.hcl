// Packer HCL scaffold for Proxmox (optional)
// Adapt this to your Packer and Proxmox setup; do not bake secrets.

packer {
  required_version = ">= 1.7.0"
}

source "qemu" "ubuntu-24" {
  iso_url = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  communicator = "ssh"
  ssh_username = "ubuntu"
}

build {
  sources = ["source.qemu.ubuntu-24"]
  provisioner "shell" {
    script = "{{template_dir}}/scripts/bootstrap-Jake.sh"
  }
}
