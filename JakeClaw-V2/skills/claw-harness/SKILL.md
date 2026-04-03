---
name: claw_harness
version: "1.0.0"
description: "Run any claw-code tool safely with logging and destructive-action confirmation"
---

# Skill: claw_harness

The primary way for Jake to invoke claw-code tools. Wraps every call with
logging, safety checks, and an optional confirmation gate for destructive
operations.

## When to Use This Skill

Use `claw_harness` whenever:
- Running any claw-code built-in or custom tool
- You are unsure which specific tool to call (run `claw manifest` first)
- The action involves file writes, deletions, or service restarts
- You want a logged record of what was invoked

## Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| command | string | **yes** | The claw tool name to invoke |
| args | array of strings | no | Arguments to pass to the tool |
| project_path | string | no | Working directory (defaults to /Jake-data/workspace) |
| confirm_destructive | boolean | no | Must be `true` for destructive commands |

## Usage

```yaml
skill: claw_harness
command: read_file
args: ["/JakeClaw/JakeClaw-V2/config/Jake-identity.md"]
project_path: /JakeClaw
```

```yaml
skill: claw_harness
command: delete_file
args: ["/Jake-data/workspace/old-output.txt"]
confirm_destructive: true
```

## Safety Rules

1. **Destructive commands** (delete, overwrite, reset, stop) require `confirm_destructive: true`.
   Without it, the skill will stop and ask for confirmation.
2. Always describe what will change before executing.
3. Log every invocation to `/Jake-data/logs/claw-invocations.log`.
4. Report errors clearly and offer rollback steps where possible.
5. When unsure what tools are available, run `claw manifest` first.

## Implementation

Calls `wrap-claw.sh` with the provided arguments:

```bash
bash /JakeClaw/JakeClaw-V2/skills/claw-harness/tools/wrap-claw.sh \
  --command <command> \
  --args <args...> \
  --project-path <path>
```
