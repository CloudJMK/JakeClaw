---
name: self_improvement
version: "1.0.0"
description: "On-demand trigger for Jake's self-improvement actions (pull, rebuild, reload skills)"
---

# Skill: self_improvement

Allows Jake (or the user) to trigger self-improvement actions on demand,
outside of the scheduled timer. All modification actions require explicit
user confirmation.

## When to Use This Skill

- You want Jake to pull the latest repo changes right now
- You have pushed new skills or config and want them reloaded immediately
- You want to check the status of the last improvement run
- You need to roll back a bad claw-code build

## Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| request_type | string (enum) | **yes** | See action table below |
| description | string | no | Human-readable note about why you're doing this |
| tool_name | string | no | For `install_tool`: the tool/package name |
| tool_source | string | no | For `install_tool`: URL or apt/pip/npm package identifier |

## Actions

| request_type | What it does |
|---|---|
| `pull_latest` | `git pull --ff-only` on the JakeClaw repo |
| `rebuild_claw` | Rebuild claw-code from source, restart services |
| `reload_skills` | Run expose-claw-tools.sh, notify OpenClaw to reload |
| `install_tool` | Install a new tool or package (requires description + confirmation) |
| `rollback_claw` | Restore `/usr/local/bin/claw.bak` — undo last rebuild |
| `status` | Show last improvement log, service states, binary hash |
| `full_update` | Pull + rebuild + reload in sequence |

## Usage

```yaml
skill: self_improvement
request_type: pull_latest
description: "I just pushed new config — pull it now"
```

```yaml
skill: self_improvement
request_type: full_update
```

```yaml
skill: self_improvement
request_type: rollback_claw
description: "New build broke the claw API"
```

## Safety

- `rebuild_claw`, `install_tool`, and `rollback_claw` always prompt for confirmation.
- `pull_latest` is safe (fast-forward only — never force).
- All actions are logged to `/Jake-data/logs/self-improvement.log`.

## Manual Timer Control

```bash
# Trigger now:
sudo systemctl start jake-self-improve.service

# Check timer status:
systemctl status jake-self-improve.timer

# View logs:
tail -f /Jake-data/logs/self-improvement.log
```
