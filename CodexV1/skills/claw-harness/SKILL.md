---
name: claw_harness
description: Execute structured Claw-code harness commands from the Jake environment.
parameters:
  command:
    type: string
    description: Claw subcommand to execute, for example manifest or run-tool.
  args:
    type: array
    description: Additional arguments to pass to the claw binary.
    items:
      type: string
  project_path:
    type: string
    description: Optional working directory for the command.
  confirm_destructive:
    type: boolean
    description: Must be true before destructive commands are allowed.
required:
  - command
---

# claw_harness

Use this skill when Jake needs structured tooling from the Claw-code harness instead of raw shell execution.

## Rules

- Log every invocation to `/Jake-data/logs/skills/claw-harness.log`.
- If the command is destructive or mutates global state, require `confirm_destructive: true`.
- Prefer `manifest`, `run-tool`, and targeted build commands over ad-hoc shell pipelines.

## Wrapper

Run `tools/wrap-claw.sh` with the requested command and args.
