---
name: self_improvement
description: Request new capabilities, rebuild Claw-code, manage tools, or improve Jake
parameters:
  - name: request_type
    type: string
    enum: ["new_capability", "rebuild_claw", "install_tool", "survey_repo", "optimize"]
    description: "Type of improvement"
  - name: description
    type: string
    description: "Detailed description of what Jake should build or improve"
---

## Usage Rules
Use this meta-skill to trigger the self-improvement loop: git pull, rebuild Claw-code, reload skills, or request new tooling. Actions that may be destructive must include a confirmation step.

Examples:
- `rebuild_claw`: "Trigger immediate rebuild of Claw-code from main branch"
- `new_capability`: "Implement a JSON validator tool"

The agent must log a post-action summary and any rollback steps.
