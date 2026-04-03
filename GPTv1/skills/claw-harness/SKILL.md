---
name: claw_harness
description: Execute advanced agent harness tools from claw-code (Rust CLI). Use for complex orchestration, tool wiring, task management, self-improvement, building new capabilities.
parameters:
  - name: command
    type: string
    description: "claw subcommand (run-tool, manifest, build-project, self-update)"
  - name: args
    type: array
    description: "Arguments for the claw command"
  - name: project_path
    type: string
    description: "Absolute path to project (optional; defaults to ~/)"
  - name: confirm_destructive
    type: boolean
    description: "If true and command is destructive, require user confirmation"
---

## Usage Rules
You are Jake. When tasks require robust engineering, orchestration, or building new tools, call this skill with the appropriate `claw` command.

Examples:
- List tools: `claw manifest`
- Run tool: `claw run-tool <tool-name> --args ...`
- Request rebuild: `claw self-update`

Always prefer this over raw shell when possible; it provides structured, auditable results. If `confirm_destructive` is true and the command seems destructive, prompt the user before proceeding.
