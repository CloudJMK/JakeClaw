# JakeClaw Deployment Guide (Draft)

## Prerequisites
- Proxmox host with Ubuntu 24.04 cloud-init template available.
- SSH keypair on the deployment machine.
- Access to the target Proxmox (CLI or API token).

## Quick Start
1. Clone this repo locally.
2. Edit `GPTv1/templates/cloud-init/user-data.yaml` and replace `{{SSH_PUBLIC_KEY}}` with your public key.
3. Create a Proxmox VM from the Ubuntu cloud-init template, inject `user-data.yaml`, and boot.
4. SSH into the VM as `jake` and run `/opt/jake-scripts/bootstrap-Jake.sh` (or adapt path in cloud-init).
5. Run `GPTv1/scripts/deploy-test.sh` to validate services.

## Customization
- `config/continue-config.yaml` sets the Continue.dev model/backend.
- `config/openclaw-config.json` configures OpenClaw skill directories.

## Troubleshooting
- If `claw` binary missing: ensure `scripts/install-claw-code.sh` ran successfully.
- If code-server not reachable: check `systemctl status code-server@jake` and firewall settings.

## Security
- Use a secrets manager (Doppler/Vault) for API keys — do NOT commit `.env` with secrets.
- Restrict external access to ports (8080, 8081, 8000) via firewall or reverse proxy.
