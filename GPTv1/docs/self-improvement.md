# Self-Improvement Loop (Draft)

Jake's self-improvement loop is implemented as a systemd timer that runs a worker script periodically.

Behavior:
- On schedule, the worker does:
  1. `git pull origin main` (non-destructive; skips if local modifications exist).
  2. Rebuild `claw-code` (`cargo build --release`).
  3. Run `scripts/expose-claw-tools.sh` to refresh skills.
  4. Log results to `/Jake-data/logs/`.

Safety:
- If local changes exist, the worker exits and alerts the user.
- Build failures are logged; optionally revert to last known-good binary if configured.
- For any potentially destructive action (DB migration, data removal), require manual confirmation.

Triggering on-demand:
- Manual: `sudo systemctl start jake-self-improve.service`
- To see next scheduled run: `systemctl list-timers | grep jake-self-improve`

Rollback policy (recommended):
- Keep a symlinked `claw` binary with versioned backups in `/usr/local/bin/claw.bak.<timestamp>`.
- On failed build, point symlink back to last good binary and notify user.
