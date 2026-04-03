# Deployment Guide

## Status

This draft is intended to be practical, but it still depends on environment-specific values before a real deploy can succeed. Use the note files in `task-notes/` as your final checklist.

## Prerequisites

- Proxmox host with a prepared Ubuntu cloud-image template
- Access to `qm` and `pvesh` on the Proxmox node
- A real SSH public key
- A repository URL and branch for this JakeClaw implementation
- Any required OpenClaw, Claw-code, and model-provider credentials

## Quick start

1. Fill in `config/.env.example` and save the real file as `config/.env` on the target repo checkout.
2. Replace placeholders in `templates/cloud-init/user-data.yaml`.
3. Review the network model in `templates/cloud-init/network-config.yaml`.
4. Dry-run VM creation:

```bash
bash templates/proxmox/create-Jake-vm.sh \
  --name jake-lab \
  --memory 8192 \
  --cores 4 \
  --ip 192.168.1.50/24 \
  --gateway 192.168.1.1 \
  --storage local-lvm \
  --template-id 9000 \
  --ssh-key /root/.ssh/id_ed25519.pub \
  --dry-run
```

5. Run the same command without `--dry-run` to create and start the VM.
6. After first boot, SSH into the VM and inspect:

```bash
sudo tail -n 200 /var/log/jake-cloud-init-bootstrap.log
sudo tail -n 200 /var/log/jake-bootstrap.log
```

7. Run deployment smoke tests:

```bash
cd /opt/JakeClaw
bash scripts/deploy-test.sh
```

## Manual recovery

- If cloud-init failed before the repo clone step, fix the placeholders and rebuild the VM.
- If `bootstrap-Jake.sh` failed mid-run, update `config/.env` and rerun the specific script with `--force`.
- If the self-improvement timer misbehaves, disable it with `sudo systemctl disable --now jake-self-improve.timer` and inspect `/Jake-data/logs/jake-self-improve.log`.

## Production hardening ideas

- Replace password auth in code-server with a reverse proxy plus SSO.
- Store `config/.env` outside the repo and inject it through a secret manager.
- Restrict inbound access to the code-server and OpenClaw ports.
- Add backup coverage for `/Jake-data`.
