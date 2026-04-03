---
name: self_improvement
description: Request safe repo updates, capability growth, rebuilds, and maintenance workflows for Jake.
parameters:
  request_type:
    type: string
    enum:
      - refresh_repo
      - rebuild_claw
      - reload_skills
      - add_capability
      - inspect_failure
  description:
    type: string
    description: Human-readable reason for the request.
required:
  - request_type
  - description
---

# self_improvement

Use this skill when Jake needs to improve or repair his own environment in a controlled way.

## Rules

- Log requests to `/Jake-data/logs/skills/self-improvement.log`.
- Prefer running `scripts/setup-self-improvement.sh` or `/usr/local/bin/jake-self-improve.sh` rather than improvising.
- Never force-reset the repo. If local changes exist, stop and report them.
- Use confirmation gates for any service reload or binary replacement that could interrupt active work.
