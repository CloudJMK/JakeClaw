# Packer Build Guide (Optional)

> **Status**: Optional / Experimental  
> **Value**: Pre-baked images reduce deployment from ~5 minutes to ~30 seconds.

---

## When to Use Packer vs Cloud-init

| Approach | Deployment time | Use case |
|---|---|---|
| Cloud-init + bootstrap | ~3-5 min | Development, small teams, manual deploys |
| Pre-baked Packer image | ~30 sec | Production, many deployments, client handoffs |

For a personal home server with rare deployments, **cloud-init is sufficient**.
Use Packer if you're deploying Jake to multiple Proxmox hosts or want zero-wait installs.

---

## Prerequisites

```bash
# Install Packer
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor \
  -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y packer

# Install Proxmox plugin
packer plugins install github.com/hashicorp/proxmox
```

**Proxmox API token** with these permissions:
- `VM.Allocate`, `VM.Config.*`, `VM.PowerMgmt`, `Datastore.AllocateSpace`
- Create at: Datacenter → Permissions → API Tokens

---

## Configuration

### USER INPUT REQUIRED

Create a var file (gitignored):

```bash
# packer/jake.pkrvars.hcl  (do NOT commit this file)
proxmox_url          = "https://192.168.1.10:8006/api2/json"
proxmox_node         = "pve"
proxmox_token_id     = "root@pam!packer"
proxmox_token_secret = "your-token-secret-here"
ssh_public_key       = "ssh-ed25519 AAAA... your-key"
jakeclaw_repo        = "https://github.com/CloudJMK/JakeClaw.git"
```

---

## Build

```bash
cd packer/

# Validate first
packer validate \
  -var-file="jake.pkrvars.hcl" \
  proxmox-ubuntu-jake.pkr.hcl

# Build the template
packer build \
  -var-file="jake.pkrvars.hcl" \
  proxmox-ubuntu-jake.pkr.hcl
```

This will:
1. Download Ubuntu 24.04 cloud image
2. Create a VM, boot it, wait for cloud-init + bootstrap to complete
3. Run `deploy-test.sh` to verify health
4. Cloud-init clean (so the template re-runs cloud-init on first clone)
5. Convert the VM to a Proxmox template (VMID: 9001 by default)

Build time: ~15-25 minutes (mostly Rust compilation).

---

## Deploy from Pre-baked Template

After the Packer build, use `create-Jake-vm.sh` pointing to the new template:

```bash
bash templates/proxmox/create-Jake-vm.sh \
  --name my-jake \
  --template 9001 \
  --memory 8192 \
  --cores 4
```

First boot takes ~30 seconds (cloud-init just sets hostname/SSH key/IP; no bootstrap needed).

---

## Security Notes

- **No secrets are baked into the image.** The `ANTHROPIC_API_KEY` and other
  secrets must be provided at first boot via cloud-init `user-data.yaml` or Doppler.
- The Packer build uses a temporary SSH key for provisioning only.
- `cloud-init clean` is run before templating to remove build-time identity.
- The var file (`jake.pkrvars.hcl`) must be in `.gitignore` — it contains
  your Proxmox token secret.

---

## Troubleshooting

| Problem | Solution |
|---|---|
| SSH timeout | Increase `ssh_timeout` in the pkr.hcl; bootstrap is slow on first run |
| ISO download fails | Pre-download the cloud image and change `iso_url` to a local path |
| Packer can't reach Proxmox API | Check firewall; try `insecure_skip_tls_verify = true` |
| Bootstrap verification fails | SSH to the VM mid-build and inspect `/var/log/jake-bootstrap.log` |
| Template not appearing in Proxmox | Check VMID 9001 isn't already in use; adjust `template_vm_id` |
