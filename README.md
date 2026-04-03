JakeClaw-V2
Jake is your personal AI assistant, running as a private VM in your home lab on Proxmox.

He has access to a terminal, your code, the web, and a set of skills he updates himself. You talk to him through a browser-based VS Code editor (code-server) with the Continue.dev extension.

What Jake Can Do
Read and edit code, run shell commands, search the web
Manage his own tool set — he rebuilds and reloads his tools on a schedule
Route AI requests through your choice of model (Claude, OpenAI, Ollama, or local)
Persist everything on a separate data disk so a VM rebuild doesn't lose your work
Quick Start
New to Proxmox VMs? Don't worry — follow the full step-by-step guide in docs/deployment-guide.md. It walks you through everything from zero.

If you're comfortable with Proxmox and just want the short version:

1. Copy and fill in your secrets

cp JakeClaw-V2/config/.env.example ../.env
nano ../.env   # Fill in ANTHROPIC_API_KEY, CODE_SERVER_PASSWORD, etc.
2. Create the VM (run on your Proxmox host)

bash JakeClaw-V2/templates/proxmox/create-Jake-vm.sh \
  --name jake \
  --memory 4096 \
  --cores 2
3. Wait for cloud-init to finish (~5 minutes), then SSH in:

ssh jake@<VM-IP>
4. Verify everything is running

bash /JakeClaw/JakeClaw-V2/scripts/deploy-test.sh
5. Open Jake's IDE in your browser

http://<VM-IP>:8080
That's it — Jake is running.

Repository Layout
JakeClaw-V2/
├── config/
│   ├── .env.example          # All variables — copy to ../.env and fill in
│   ├── Jake-identity.md      # Who Jake is and how he behaves
│   ├── continue-config.yaml  # Continue.dev IDE integration config
│   └── openclaw-config.json  # Claude-code / OpenClaw settings
│
├── scripts/
│   ├── bootstrap-Jake.sh     # Main entry point (called by cloud-init)
│   ├── install-dev-env.sh    # Git, Node.js 24, Rust, Python, jq
│   ├── install-openclaw.sh   # claude-code CLI (@anthropic-ai/claude-code)
│   ├── install-claw-code.sh  # Build claw-code from source + systemd service
│   ├── install-code-server.sh# Browser VS Code on port 8080
│   ├── install-continue-dev.sh # Continue.dev extension
│   ├── setup-jake-api.sh     # LiteLLM API proxy on port 8000
│   ├── setup-self-improvement.sh # Scheduled self-improvement timer
│   ├── expose-claw-tools.sh  # Generate skill files from claw manifest
│   └── deploy-test.sh        # Smoke test suite (run after deploy)
│
├── templates/
│   ├── cloud-init/
│   │   ├── user-data.yaml    # cloud-init config for first boot
│   │   └── network-config.yaml
│   └── proxmox/
│       └── create-Jake-vm.sh # VM creation script (run on Proxmox host)
│
├── skills/
│   ├── claw-harness/         # Core skill: safely run any claw-code tool
│   ├── self-improvement/     # On-demand self-improvement triggers
│   └── claw-tools-dynamic/   # Auto-generated from claw manifest (gitignored)
│
├── docs/
│   ├── deployment-guide.md   # Full step-by-step deployment walkthrough
│   ├── claw-code-integration.md
│   ├── self-improvement.md
│   └── packer.md             # Optional: bake a reusable VM image
│
└── packer/
    └── proxmox-ubuntu-jake.pkr.hcl
Key Design Choices
Decision	Choice	Why
VM vs LXC	VM	Full kernel isolation; better for running services
First boot	cloud-init	Standard, provider-agnostic, idempotent
IDE	code-server	Browser-based VS Code, no client install needed
AI bridge	Continue.dev	First-class IDE integration, easy model switching
API proxy	LiteLLM	OpenAI-compatible — works with Claude, OpenAI, Ollama
Self-update	systemd timer	Reliable, no cron deps, restarts on failure
Persistence	Second disk	Survives VM rebuild; symlinked into home dirs
Ports
Port	Service
8080	code-server (IDE)
8000	Jake API (LiteLLM proxy)
8081	claw-code tool server
3000	OpenClaw admin/reload
Need Help?
First deployment? → docs/deployment-guide.md
Something broken? → Run bash /JakeClaw/JakeClaw-V2/scripts/deploy-test.sh --verbose
Change the AI model? → Edit JAKE_API_BACKEND in your ../.env, then restart jake-api.service
Jake stuck? → Check logs: journalctl -u jake-api -u claw-code -u code-server@jake -f
