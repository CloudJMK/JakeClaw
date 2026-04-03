# Self-Improvement Guide

Jake is designed to maintain and improve himself over time. This doc covers
how the self-improvement loop works, how to trigger it manually, and how to
recover from failed updates.

---

## How It Works

The self-improvement loop is a **systemd timer** that fires every 6 hours
(default: 02:00, 08:00, 14:00, 20:00 UTC).

Each cycle:

```
1. git pull /JakeClaw (ff-only — never force-reset)
        ↓
2. Check if claw-code source hash changed
        ↓ (if changed)
3. Backup /usr/local/bin/claw → claw.bak
        ↓
4. cargo build --release
        ↓ (success)               ↓ (failure)
5. Install new binary      5b. Rollback to claw.bak
        ↓
6. Regenerate dynamic skills (expose-claw-tools.sh)
        ↓
7. Restart claw-code.service + jake-api.service
        ↓
8. Log result to /Jake-data/logs/self-improvement.log
```

---

## Files

| File | Purpose |
|---|---|
| `/usr/local/bin/jake-self-improve.sh` | Worker script |
| `/etc/systemd/system/jake-self-improve.service` | Systemd service (oneshot) |
| `/etc/systemd/system/jake-self-improve.timer` | Systemd timer |
| `/Jake-data/logs/self-improvement.log` | Execution log |
| `/var/lib/jake/claw-installed-hash` | Last built git hash (skip-rebuild guard) |

---

## Checking Status

```bash
# Timer status and next fire time
systemctl status jake-self-improve.timer

# Service status (of last run)
systemctl status jake-self-improve.service

# Full log
cat /Jake-data/logs/self-improvement.log

# Tail live
journalctl -u jake-self-improve.service -f
```

---

## Manual Trigger

```bash
# Trigger an immediate improvement cycle:
sudo systemctl start jake-self-improve.service

# Watch it run:
journalctl -u jake-self-improve.service -f
```

Or ask Jake via the self_improvement skill:
```
request_type: full-update
description: "Pull latest code and rebuild claw-code"
```

Jake will confirm before proceeding and report the outcome.

---

## Changing the Schedule

Edit `/etc/systemd/system/jake-self-improve.timer` or set `JAKE_IMPROVE_SCHEDULE`
in `config/.env` and re-run `setup-self-improvement.sh`:

```bash
# Examples:
JAKE_IMPROVE_SCHEDULE="*-*-* 03:00:00"          # once daily at 3am
JAKE_IMPROVE_SCHEDULE="*-*-* 00,06,12,18:00:00" # every 6h at top-of-hour
JAKE_IMPROVE_SCHEDULE="Mon *-*-* 02:00:00"       # weekly on Mondays
```

After editing:
```bash
sudo systemctl daemon-reload
sudo systemctl restart jake-self-improve.timer
```

---

## Rollback

### Automatic (on build failure)

If `cargo build` fails, the worker script automatically restores the backup:

```
cp /usr/local/bin/claw.bak /usr/local/bin/claw
```

This means Jake is **never left without a working claw binary** after a failed
rebuild.

### Manual rollback

```bash
# Restore previous binary:
sudo cp /usr/local/bin/claw.bak /usr/local/bin/claw
sudo systemctl restart claw-code.service jake-api.service

# Verify:
claw --version
```

### Rollback via self_improvement skill

```
request_type: rollback-claw
```

Jake will confirm, restore claw.bak, and restart affected services.

---

## What Self-Improvement Does NOT Do

- **Never `git reset --hard`** or force-pull. If local changes exist, the pull
  is skipped and logged. Commit or stash changes to re-enable auto-pull.
- **Never modifies user data** in `/Jake-data/`.
- **Never touches config/.env** or secrets.
- **Never upgrades system packages** (apt) automatically — only claw-code and
  skills are updated.

---

## On-Demand Capability Requests

Jake can also proactively identify missing capabilities and request them:

> "I need a tool to parse PDF files. I'll install `pdfplumber` via pip.
>  Shall I proceed?"

This is handled by the `self_improvement` skill with `request_type: install-tool`.
Jake always asks before installing.

---

## Disabling the Timer

```bash
# Stop and disable:
sudo systemctl stop jake-self-improve.timer
sudo systemctl disable jake-self-improve.timer

# Re-enable:
sudo systemctl enable --now jake-self-improve.timer
```

---

## Logs Reference

```
/Jake-data/logs/self-improvement.log   — timer run history
/Jake-data/logs/claw-invocations.log   — every claw CLI call
/Jake-data/logs/expose-claw-tools.log  — skill regeneration history
/var/log/jake-bootstrap.log            — first-boot bootstrap log
```
