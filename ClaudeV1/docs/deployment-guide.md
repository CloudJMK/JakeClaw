# JakeClaw Deployment Guide

> **Audience**: Anyone deploying a Jake instance on a Proxmox host.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Proxmox VE 8.x host | Earlier versions may work but are untested |
| Ubuntu 24.04 cloud-init template | See "Prepare the Template" below |
| SSH key pair | For the `jake` user |
| Anthropic API key | For OpenClaw (Claude Code) — get at console.anthropic.com |
| ~10 GB free storage | Root disk (40 GB recommended) + Jake-data disk (20 GB) |

> **USER INPUT REQUIRED**: Anthropic API key and SSH public key must be set
> before deploying. See [Quick Start](#quick-start).

---

## Quick Start (< 5 minutes)

### 1. Clone the repo

```bash
git clone https://github.com/CloudJMK/JakeClaw.git
cd JakeClaw/ClaudeV1
```

### 2. Configure

```bash
cp config/.env.example config/.env
# Edit config/.env — fill in at minimum:
#   ANTHROPIC_API_KEY=...
#   PROXMOX_TEMPLATE_ID=...   (your Ubuntu 24.04 template ID)
#   PROXMOX_STORAGE=...       (e.g. local-lvm)

# Inject your SSH key into cloud-init template
SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
sed -i "s|{{SSH_PUBLIC_KEY}}|${SSH_KEY}|g" templates/cloud-init/user-data.yaml
sed -i "s|{{JAKECLAW_REPO}}|https://github.com/CloudJMK/JakeClaw.git|g" \
  templates/cloud-init/user-data.yaml
```

### 3. Deploy

```bash
# On your Proxmox host (or via SSH to it):
bash templates/proxmox/create-Jake-vm.sh \
  --name my-jake \
  --memory 8192 \
  --cores 4

# Watch first-boot bootstrap (~3-5 min):
ssh jake@<VM_IP> "tail -f /var/log/jake-bootstrap.log"
```

### 4. Verify

```bash
ssh jake@<VM_IP> "bash /JakeClaw/scripts/deploy-test.sh"
```

### 5. Connect

- **Browser IDE**: `http://<VM_IP>:8080` → Open Continue sidebar (Ctrl+L)
- **SSH**: `ssh jake@<VM_IP>`
- **API**: `curl http://<VM_IP>:8000/v1/models`

---

## Prepare the Ubuntu 24.04 Template (one-time on Proxmox host)

```bash
# Download Ubuntu 24.04 cloud image
wget -O /var/lib/vz/template/iso/ubuntu-24.04-cloud.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# Create a template VM (adjust storage/node as needed)
qm create 9000 --name ubuntu-2404-template --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --ostype l26

qm importdisk 9000 /var/lib/vz/template/iso/ubuntu-24.04-cloud.img local-lvm

qm set 9000 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-9000-disk-0 \
  --ide2 local-lvm:cloudinit \
  --boot c --bootdisk scsi0 \
  --serial0 socket --vga serial0 \
  --agent enabled=1

qm template 9000
```

---

## Manual Deploy (step-by-step without create-Jake-vm.sh)

```bash
# 1. Clone template
qm clone 9000 101 --name jake --full --storage local-lvm

# 2. Configure hardware
qm set 101 --memory 8192 --cores 4 --balloon 0

# 3. Resize disks
qm resize 101 scsi0 40G
qm set 101 --scsi1 local-lvm:20,discard=on   # /Jake-data

# 4. Upload cloud-init snippets
cp templates/cloud-init/*.yaml /var/lib/vz/snippets/

# 5. Apply cloud-init
qm set 101 \
  --ipconfig0 ip=dhcp \
  --cicustom "user=local:snippets/user-data.yaml,network=local:snippets/network-config.yaml" \
  --agent enabled=1,fstrim_cloned_disks=1

# 6. Start
qm start 101
```

---

## Customization

### Static IP

Edit `templates/cloud-init/network-config.yaml` — uncomment the static section
and fill in `{{STATIC_IP}}`, `{{GATEWAY_IP}}`, `{{DNS_SERVERS}}`.

### Different model backend

In `config/.env`, set `JAKE_API_BACKEND=anthropic` (or `openai`) and add
the corresponding API key. Then re-run `setup-jake-api.sh`.

### Adjust self-improvement schedule

In `config/.env`:
```bash
JAKE_IMPROVE_SCHEDULE="*-*-* 03:00:00"   # once daily at 3am UTC
```
Then re-run `setup-self-improvement.sh`.

### Add skills

Drop a `SKILL.md` file in `/Jake-data/skills/<skill-name>/` — it will be
picked up automatically by OpenClaw (the directory is in `extraDirs`).

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Bootstrap hangs | `journalctl -u cloud-init -f` on the VM |
| claw: command not found | `bash /JakeClaw/scripts/install-claw-code.sh` |
| API returns 502 | `systemctl status jake-api.service` + `systemctl status claw-code.service` |
| Continue can't connect | Check `~/.continue/config.yaml` apiBase |
| Self-improvement fails | `cat /Jake-data/logs/self-improvement.log` |
| code-server blank page | `systemctl restart code-server.service` |

### Recovery: rollback claw binary

```bash
# If a rebuild broke claw:
sudo cp /usr/local/bin/claw.bak /usr/local/bin/claw
sudo systemctl restart claw-code.service jake-api.service
```

---

## Production Hardening (⚠ experimental)

> The default setup is designed for a **private home network** (no hostile actors).
> If exposing Jake to the internet, add:

- Tailscale or WireGuard VPN instead of direct port exposure
- code-server password (`CODE_SERVER_PASSWORD` in `.env`)
- Nginx reverse proxy with TLS (Let's Encrypt)
- Fail2ban on SSH
- Doppler for secrets management

See the [Doppler docs](https://docs.doppler.com) for integrating with JakeClaw.
