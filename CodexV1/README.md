# JakeClaw CodexV1

`CodexV1` is an independent rough-draft implementation of the JakeClaw project. It is structured as a reproducible Ubuntu VM build for Proxmox that bootstraps a "Jake" agent workstation with cloud-init, system services, OpenClaw integration points, Claw-code bridge scripts, a Continue.dev IDE experience, and a self-improvement loop.

This draft intentionally uses placeholders for anything that depends on your environment:

- SSH public keys
- Proxmox template IDs and storage targets
- Git remotes and private branches
- OpenClaw / Claw-code repository URLs
- API tokens, proxy credentials, and external endpoints

Those inputs are tracked in [`task-notes/`](./task-notes) so the repo can be built in earnest without inventing secrets or host-specific values.

## Threat Model

Jake is treated as a trusted home-lab or small-team operator. The main goal is preventing accidental damage, not defending against a hostile tenant. This repo therefore favors:

- Broad read and write access inside the VM
- Confirmation gates around destructive actions
- Idempotent automation so rebuilds are safe
- Clear logs and recovery paths when an update fails

## What Is Included

- Cloud-init templates for first-boot provisioning
- Modular install scripts for dev tooling, code-server, Continue.dev, OpenClaw, Claw-code, and the API wrapper
- OpenClaw skill definitions for the harness bridge and self-improvement requests
- Proxmox VM creation helper
- Self-improvement systemd timer and worker logic
- Deployment smoke tests
- CI validation workflow
- Optional Packer template for pre-baked images

## Quick Start

1. Copy `config/.env.example` to a real `.env` file on the target VM or inject the values through your secret manager.
2. Replace placeholders in `templates/cloud-init/user-data.yaml` and `templates/cloud-init/network-config.yaml`.
3. Use `templates/proxmox/create-Jake-vm.sh --dry-run` to review the generated `qm` commands.
4. Boot the VM and let cloud-init clone the repo and run `scripts/bootstrap-Jake.sh`.
5. Run `bash scripts/deploy-test.sh` as the `jake` user to confirm the deployment.

## Layout

```text
CodexV1/
  .github/
  ansible/
  claw-code/
  config/
  docs/
  packer/
  scripts/
  skills/
  task-notes/
  templates/
```

## Notes On Missing Inputs

This repo does not hardcode real credentials, SSH keys, or environment-specific hostnames. Every script includes comments where a human needs to supply:

- credentials
- API keys
- private repository locations
- trusted domains / certificates
- Proxmox host details

See the matching note files in [`task-notes/`](./task-notes) before a real deployment.
