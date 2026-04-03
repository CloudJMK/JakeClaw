# claw-code Integration

## Overview

claw-code is Jake's primary tool-use engine. It exposes a set of tools
(read, write, bash, search, etc.) as an HTTP API that the OpenClaw skill
router can call.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  You (via Continue.dev IDE)                     │
└──────────────────────┬──────────────────────────┘
                       │ chat / edit
                       ▼
┌─────────────────────────────────────────────────┐
│  Jake API (LiteLLM on :8000)                    │
│  OpenAI-compatible proxy → your chosen model    │
└──────────────────────┬──────────────────────────┘
                       │ tool calls
                       ▼
┌─────────────────────────────────────────────────┐
│  claw-code server (:8081)                       │
│  Serves tool manifest + executes tool calls     │
└──────────────────────┬──────────────────────────┘
                       │ skill dispatch
                       ▼
┌─────────────────────────────────────────────────┐
│  OpenClaw (:3000)                               │
│  Routes tool calls to skill SKILL.md handlers  │
└─────────────────────────────────────────────────┘
```

## How Skills Are Generated

When `expose-claw-tools.sh` runs (on bootstrap and via the self-improvement
timer), it:

1. Calls `claw manifest --json` to get the list of available tools
2. Parses the JSON (or plain-text fallback)
3. Writes one `SKILL.md` file per tool into `skills/claw-tools-dynamic/`
4. Notifies OpenClaw to reload its skill list

This means Jake's skill list stays in sync with what claw-code actually
supports without any manual updates.

## Rebuild Detection

`install-claw-code.sh` computes a SHA-256 hash of all `*.rs` source files
and stores it in `/var/lib/jake/claw-installed-hash`. On subsequent runs
(bootstrap --force or self-improvement), it skips the expensive cargo build
if nothing has changed.

## Rollback

Before any rebuild, the existing binary is backed up to `/usr/local/bin/claw.bak`.
If the build fails, the backup is automatically restored. You can also
trigger a manual rollback via the `self_improvement` skill with
`request_type: rollback_claw`.

## Adding Custom Tools

1. Write your tool logic (any language) and expose it from claw-code
2. Re-run `expose-claw-tools.sh` or trigger `reload_skills` via the skill
3. The new SKILL.md appears in `skills/claw-tools-dynamic/` automatically

## Checking Tool Availability

```bash
# As jake user:
/usr/local/bin/claw manifest
/usr/local/bin/claw manifest --json | python3 -m json.tool
```
