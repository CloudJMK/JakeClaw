# JakeClaw — ClaudeV1

> Claude's independent implementation of the JakeClaw deployable agent-image.

JakeClaw is a reproducible, self-improving agent "image" for Proxmox. Deploy it once
and get a trusted personal agent — Jake — that surveys, maintains, and improves its own
environment, orchestrates sub-agents, and integrates Continue.dev for agentic IDE work.

---

## Threat Model

Jake is a trusted personal agent on a **private home server**.  
Goal: *don't let him accidentally break things* — not hardening against a hostile actor.  
Approach: broad read/write for high capability; confirmation gates on destructive operations.

---

## Quick Start (< 5 minutes to a running Jake)

```bash
# 1. On your Proxmox host — adjust args to taste
bash templates/proxmox/create-Jake-vm.sh \
  --name my-jake \
  --memory 8192 \
  --cores 4 \
  --storage local-lvm

# 2. When the VM boots, cloud-init runs bootstrap-Jake.sh automatically.
#    Watch progress:
ssh jake@<VM_IP> "tail -f /var/log/jake-bootstrap.log"

# 3. Verify deployment health:
ssh jake@<VM_IP> "bash /JakeClaw/scripts/deploy-test.sh"

# 4. Open the IDE:
#    http://<VM_IP>:8080  (code-server)
#    Open Continue sidebar (Ctrl+L) → "Hello Jake, survey the codebase"
```

---

## Repository Structure

```
ClaudeV1/
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   ├── deployment-guide.md
│   ├── claw-code-integration.md
│   ├── self-improvement.md
│   └── packer.md
├── templates/
│   ├── cloud-init/
│   │   ├── user-data.yaml
│   │   ├── network-config.yaml
│   │   └── README.md
│   └── proxmox/
│       └── create-Jake-vm.sh
├── scripts/
│   ├── bootstrap-Jake.sh
│   ├── install-openclaw.sh
│   ├── install-claw-code.sh
│   ├── install-dev-env.sh
│   ├── install-code-server.sh
│   ├── install-continue-dev.sh
│   ├── setup-jake-api.sh
│   ├── setup-self-improvement.sh
│   ├── expose-claw-tools.sh
│   └── deploy-test.sh
├── skills/
│   ├── claw-harness/
│   │   ├── SKILL.md
│   │   └── tools/wrap-claw.sh
│   ├── self-improvement/
│   │   └── SKILL.md
│   └── claw-tools-dynamic/   ← auto-generated at runtime
├── config/
│   ├── .env.example
│   ├── openclaw-config.json
│   ├── continue-config.yaml
│   └── Jake-identity.md
├── claw-code/               ← submodule: ultraworkers/claw-code-parity
├── packer/
│   └── proxmox-ubuntu-jake.pkr.hcl
└── ansible/
    └── site.yml
```

---

## Key Design Choices

| Decision | Rationale |
|---|---|
| Ubuntu 24.04 VM (not LXC) | Full "human at a PC" capability: GPU passthrough, real kernel, Playwright |
| Docker for side-tools only | Core Jake stays in one robust VM; containers for satellites |
| Cloud-init + bootstrap-Jake.sh | Fully automated first-boot; idempotent re-runs |
| Systemd self-improvement timer | Jake can git-pull, rebuild Claw-code, and reload skills on schedule |
| Continue.dev pre-installed | Polished agentic IDE sidebar out of the box |
| LiteLLM wrapper on :8000 | OpenAI-compatible endpoint Continue and OpenClaw can share |

---

## Deployment Prerequisites

- Proxmox VE host (tested on 8.x)
- Ubuntu 24.04 cloud image downloaded to Proxmox storage
- SSH key pair for the `jake` user
- (Optional) Doppler account for secrets management

> **USER INPUT REQUIRED**: Fill in `config/.env.example` → `config/.env`  
> See [docs/deployment-guide.md](docs/deployment-guide.md) for full instructions.

---

## Philosophy

Jake is designed to be a **proactive human-like collaborator**:
- Plans before acting
- Confirms before destructive changes
- Logs everything to `/Jake-data/logs/`
- Self-repairs and self-improves on a timer
- Spawns sub-agents via Claw-code harness as needed
