# Self-Improvement System

Jake updates himself automatically on a systemd timer. Here's how it works,
how to control it, and what the safety boundaries are.

## What the Timer Does

Every day at 02:00, 08:00, 14:00, and 20:00 UTC (with a random ±5 minute
jitter to avoid thundering herd), the `jake-self-improve.service` runs:

1. **Pull latest** — `git pull --ff-only` on the JakeClaw repo
2. **Rebuild claw-code** — only if source files changed (hash-based check)
3. **Regenerate skills** — runs `expose-claw-tools.sh` to sync skill files
4. **Restart services** — `claw-code.service` and `jake-api.service`

All steps are logged to `/Jake-data/logs/self-improvement.log`.

## Rollback on Build Failure

Before any rebuild:
- The current binary is backed up to `/usr/local/bin/claw.bak`
- If the build fails, the backup is automatically restored
- Services are not restarted if the build fails

## Concurrent Run Protection

The worker uses `flock` on `/run/jake-self-improve.lock` to prevent two
improvement cycles from running at the same time.

## Controlling the Timer

```bash
# Check timer status and next run time
systemctl status jake-self-improve.timer

# Trigger improvement cycle now (doesn't interrupt the timer schedule)
sudo systemctl start jake-self-improve.service

# Watch live log output
tail -f /Jake-data/logs/self-improvement.log

# Disable the timer temporarily
sudo systemctl stop jake-self-improve.timer

# Re-enable the timer
sudo systemctl start jake-self-improve.timer
```

## Changing the Schedule

The schedule is controlled by `JAKE_IMPROVE_SCHEDULE` in `../.env`.
Default: `"02,08,14,20"` (4x per day at those UTC hours).

After changing, re-run:
```bash
sudo bash /JakeClaw/JakeClaw-V2/scripts/setup-self-improvement.sh
```

## On-Demand Self-Improvement

Jake can also trigger self-improvement actions on demand via the
`self_improvement` skill. See [docs/claw-code-integration.md](claw-code-integration.md)
and the skill's own [SKILL.md](../skills/self-improvement/SKILL.md).

## Safety Rules

- `git pull` is **always** `--ff-only` — Jake will never force-overwrite your repo
- Jake never deletes `/Jake-data/` without explicit confirmation
- The timer runs as root but the git operations run as the `jake` user
- All rollbacks are automatic on build failure; manual rollback is also available
