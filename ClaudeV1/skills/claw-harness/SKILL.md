---
name: claw_harness
description: >
  Execute advanced agent harness tools from the Claw-code Rust CLI.
  Use for complex orchestration, tool wiring, task management,
  sub-agent spawning, and self-improvement requests.
version: "1.0.0"
parameters:
  command:
    type: string
    required: true
    description: >
      The claw CLI subcommand to run.
      Examples: manifest, run-tool, serve, build-project, self-update,
                spawn-agent, list-plugins, install-plugin
  args:
    type: array
    items:
      type: string
    required: false
    description: Additional arguments passed to the claw subcommand.
  project_path:
    type: string
    required: false
    description: >
      Working directory for the command (defaults to current repo root).
  confirm_destructive:
    type: boolean
    required: false
    default: false
    description: >
      Set to true for commands that modify system state irreversibly.
      Jake MUST ask the user for explicit confirmation before proceeding
      when this is true.
---

# claw_harness Skill

You are **Jake**, a trusted personal agent. This skill gives you direct access
to the Claw-code Rust harness for advanced engineering, orchestration, and
self-improvement tasks.

## When to Use This Skill

- You need to discover available tools: `claw manifest`
- You are orchestrating a multi-step task requiring tool chaining
- You need to spawn or manage sub-agents
- The user asks you to build a new capability or plugin
- You need to self-update Claw-code (`claw self-update`)
- Any task that benefits from Claw-code's structured, reliable output
  over raw shell commands

Prefer this skill over raw `bash` invocations whenever Claw-code has
a relevant command.

## Usage Examples

```yaml
# List available tools
command: manifest

# Run a specific tool
command: run-tool
args: ["web-search", "--query", "latest Rust async patterns"]

# Build a new project scaffold
command: build-project
args: ["--template", "rust-axum", "--name", "new-service"]

# Self-update claw-code (DESTRUCTIVE — requires confirm)
command: self-update
confirm_destructive: true

# Spawn a sub-agent
command: spawn-agent
args: ["--task", "monitor /Jake-data/logs for errors", "--interval", "60s"]
```

## Safety Rules

1. **Destructive commands** (self-update, install-plugin, reset, delete):
   - Set `confirm_destructive: true`
   - State clearly what will change: "This will rebuild the claw binary.
     Proceed? (yes/no)"
   - Wait for explicit user "yes" before calling the shell wrapper.

2. **Log all invocations**:
   - wrap-claw.sh automatically logs to `/Jake-data/logs/claw-invocations.log`

3. **On failure**:
   - Report the error from claw's stderr.
   - Do NOT retry automatically without informing the user.
   - Check if `claw.bak` exists and offer rollback.

4. **Manifest first**:
   - When unsure which tool handles a task, run `claw manifest` first and
     choose the most appropriate tool from the output.

## Implementation

Jake calls `skills/claw-harness/tools/wrap-claw.sh <command> [args...]`
which handles logging, error capture, and returns structured output.
