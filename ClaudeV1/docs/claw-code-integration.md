# Claw-code Integration Guide

Claw-code is the Rust-based agent harness that gives Jake advanced orchestration,
tool-chaining, and sub-agent capabilities. This doc explains how it's wired into
JakeClaw and how to extend it.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  User / Continue.dev sidebar                            │
└─────────────┬───────────────────────────────────────────┘
              │ HTTP (OpenAI-compatible)
              ▼
┌─────────────────────────────┐
│  jake-api.service (LiteLLM) │  :8000
│  /v1/chat/completions        │
└─────────────┬───────────────┘
              │ routes to
              ▼
┌─────────────────────────────┐    ┌──────────────────────┐
│  claw-code.service (Axum)   │    │  Anthropic API       │
│  :8081 (internal)            │    │  (if backend=        │
│  Rust harness + tools        │    │   anthropic)         │
└─────────────┬───────────────┘    └──────────────────────┘
              │
     ┌────────┴────────┐
     │                 │
     ▼                 ▼
 /usr/local/bin/claw   Dynamic tools
 (CLI)                 (plugins)
```

**Key components**:

| Component | Role |
|---|---|
| `claw` CLI | Direct tool invocation, manifest queries, plugin management |
| `claw-code.service` | Axum HTTP server exposing tools as REST endpoints |
| `jake-api.service` | LiteLLM proxy — OpenAI compat layer for Continue + OpenClaw |
| `wrap-claw.sh` | Logging wrapper called by the `claw_harness` OpenClaw skill |
| `expose-claw-tools.sh` | Generates dynamic SKILL.md files from `claw manifest` |

---

## How Tools Are Exposed

### Static Skills (hand-crafted)

`skills/claw-harness/SKILL.md` — the primary bridge skill. Jake uses this to
call any `claw` command with full control.

`skills/self-improvement/SKILL.md` — meta-skill for self-update operations.

### Dynamic Skills (auto-generated)

`scripts/expose-claw-tools.sh` queries `claw manifest` and generates a
`SKILL.md` wrapper for each tool in `skills/claw-tools-dynamic/`.

These files are gitignored and regenerated:
- At bootstrap
- By the self-improvement timer (every 6h)
- On demand: `bash /JakeClaw/scripts/expose-claw-tools.sh`

---

## Build Patterns

### First-time build (automatic via bootstrap)

```bash
# bootstrap-Jake.sh calls install-claw-code.sh which:
#   1. git clone ultraworkers/claw-code-parity → /JakeClaw/claw-code
#   2. cargo build --release
#   3. cp target/release/claw /usr/local/bin/claw
#   4. systemctl enable --start claw-code.service
```

### Rebuild manually

```bash
sudo bash /JakeClaw/scripts/install-claw-code.sh
```

Or ask Jake:
```
self_improvement: rebuild-claw
```

### Add a new plugin

```bash
# Placeholder for actual claw plugin install command
# USER INPUT REQUIRED: claw-code plugin API depends on the version you've built
claw install-plugin my-new-tool
sudo bash /JakeClaw/scripts/expose-claw-tools.sh   # regenerate skills
```

---

## OpenAI-Compatible Wrapper (LiteLLM)

The `jake-api.service` runs LiteLLM on port 8000 and routes to the configured backend.

### Config location
`/etc/litellm/config.yaml` (written by `setup-jake-api.sh`)

### Supported backends

| `JAKE_API_BACKEND` | Routes to |
|---|---|
| `claw-local` (default) | claw-code Axum server on :8081 |
| `anthropic` | Anthropic API directly |
| `openai` | OpenAI or compatible API |

### Change backend at runtime

```bash
# Edit /etc/litellm/config.yaml, then:
sudo systemctl restart jake-api.service
```

---

## Claw-code Axum Server

`claw-code.service` starts the claw-code Rust HTTP server on port 8081.

```bash
# Check status
systemctl status claw-code.service

# View logs
journalctl -u claw-code.service -f

# Manual start (if stopped)
sudo systemctl start claw-code.service
```

> **USER INPUT REQUIRED**: The exact `ExecStart` flags depend on your claw-code
> version. `install-claw-code.sh` defaults to `claw serve --port 8081`.
> Update `/etc/systemd/system/claw-code.service` if your build uses different flags.

---

## Extending Claw-code

### Add a custom Rust tool

```bash
# In the claw-code source tree:
cd /JakeClaw/claw-code/crates/tools
# Create new_tool.rs following existing patterns
# Add to Cargo.toml
cargo build --release
sudo cp target/release/claw /usr/local/bin/claw
```

Then regenerate skills:
```bash
sudo bash /JakeClaw/scripts/expose-claw-tools.sh
```

### Add a Python tool (via tools.py workspace)

```bash
# In /JakeClaw/claw-code/src/ (or wherever tools.py lives):
# Add your function following the existing decorator pattern
# Restart claw-code.service
sudo systemctl restart claw-code.service
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `claw manifest` returns empty `{}` | claw-code service not running; `systemctl start claw-code.service` |
| `cargo build` fails | Check `~/.cargo/` exists for jake user; run `rustup update` |
| Dynamic skills not appearing | Re-run `expose-claw-tools.sh`; check OpenClaw skill extraDirs config |
| LiteLLM proxy 502 | `claw-code.service` down or wrong port; check `/etc/litellm/config.yaml` |
| "placeholder" binary in use | Real claw-code build failed; see `install-claw-code.sh` logs |
