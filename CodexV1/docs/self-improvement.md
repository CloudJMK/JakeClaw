# Self-improvement

## Overview

Jake's self-improvement loop is a controlled maintenance cycle, not an unconstrained autonomous updater.

## What it does

- Uses `git pull --ff-only` on the configured repo and branch
- Refuses to run if local modifications are present
- Rebuilds Claw-code through the install script
- Regenerates dynamic Claw tool wrappers
- Logs every run to `/Jake-data/logs/jake-self-improve.log`

## Components

- `scripts/setup-self-improvement.sh`
- `/usr/local/bin/jake-self-improve.sh`
- `jake-self-improve.service`
- `jake-self-improve.timer`

## Manual trigger

```bash
sudo systemctl start jake-self-improve.service
sudo tail -n 200 /Jake-data/logs/jake-self-improve.log
```

## Rollback behavior

If the Claw-code rebuild fails and a previous binary exists, the worker copies `/usr/local/bin/claw.previous` back into place.

## Safety guidance

- Keep branch protection on the source repo.
- Review self-improvement changes before merging them into the branch Jake tracks.
- Use confirmation gates before any service reload that could interrupt active work.
