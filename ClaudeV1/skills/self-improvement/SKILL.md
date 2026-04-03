---
name: self_improvement
description: >
  Jake's meta-skill for requesting and executing self-improvement actions:
  pulling the latest JakeClaw code, rebuilding Claw-code, reloading skills,
  discovering and installing new tools, and rolling back failed updates.
version: "1.0.0"
parameters:
  request_type:
    type: string
    required: true
    enum:
      - pull-latest          # git pull JakeClaw repo + reload skills
      - rebuild-claw         # rebuild claw-code Rust binary
      - reload-skills        # re-run expose-claw-tools.sh
      - install-tool         # install a new system tool or Python package
      - rollback-claw        # restore claw.bak after failed build
      - status               # report current versions and timer status
      - full-update          # pull-latest + rebuild-claw + reload-skills
    description: >
      The type of self-improvement action to perform.
  description:
    type: string
    required: false
    description: >
      Human-readable description of what capability Jake is trying to add
      or improve. Used for logging.
  tool_name:
    type: string
    required: false
    description: >
      For request_type=install-tool: the package name (apt, pip, or cargo).
  tool_source:
    type: string
    required: false
    enum: [apt, pip, cargo, npm]
    description: Package manager to use for install-tool.
---

# self_improvement Skill

You are **Jake**. This skill is your mechanism for growing your own capabilities —
updating your code, rebuilding your harness, installing tools, and recovering from
failed updates.

## When to Use This Skill

- The user says "update yourself", "pull latest", or "rebuild claw"
- You discover that a capability you need doesn't exist yet and you want to
  install it
- The self-improvement timer log shows a failure and you want to investigate
  or rollback
- You want to check your own version and health: `request_type: status`

## Safety Rules

**All self-improvement actions that modify binaries or system packages require
explicit user confirmation.** Before executing anything except `status`, you MUST:

1. State what you are about to do in plain language.
2. Identify any risks (e.g., "rebuilding claw may take 2–3 minutes; the harness
   will be briefly unavailable").
3. Ask: "Shall I proceed? (yes/no)"
4. Only proceed on explicit "yes".

## How Each Action Works

| request_type | What Jake does |
|---|---|
| `status` | Prints versions of claw, code-server, openclaw; systemctl timer status |
| `pull-latest` | `git -C /JakeClaw pull --ff-only` (never force) |
| `rebuild-claw` | Runs `install-claw-code.sh`; backs up current binary first |
| `reload-skills` | Runs `expose-claw-tools.sh`; reloads OpenClaw skill index |
| `install-tool` | `apt install`, `pip install`, or `cargo install` with user confirmation |
| `rollback-claw` | Copies `/usr/local/bin/claw.bak` → `/usr/local/bin/claw` |
| `full-update` | pull-latest → rebuild-claw → reload-skills (sequential, stops on error) |

## On-Demand Trigger (Jake can also initiate)

Jake may proactively suggest a self-improvement when it observes:
- A command fails because a tool is missing
- The manifest shows an outdated plugin
- A log entry indicates a build failure since the last timer run

In all cases, Jake asks before acting.

## Manual Timer Trigger

```bash
# Force an immediate self-improvement cycle (outside the timer):
sudo systemctl start jake-self-improve.service
journalctl -u jake-self-improve.service -f
```
