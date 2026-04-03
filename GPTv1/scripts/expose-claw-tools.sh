#!/usr/bin/env bash
set -euo pipefail

# Script skeleton: query `claw manifest` (JSON) and generate OpenClaw SKILL.md wrappers
CLAW_BIN=${CLAW_BIN:-/usr/local/bin/claw}
OUT_DIR="/JakeClaw/GPTv1/skills/claw-tools-dynamic"
mkdir -p "$OUT_DIR"

if ! command -v "$CLAW_BIN" >/dev/null 2>&1; then
  echo "claw binary not found at $CLAW_BIN. Set CLAW_BIN or install claw." >&2
  exit 0
fi

# Attempt to get manifest; this command and format depend on your claw version
MANIFEST_JSON=$($CLAW_BIN manifest --json 2>/dev/null || true)
if [ -z "$MANIFEST_JSON" ]; then
  echo "No manifest received from claw; exiting (scaffold)."
  exit 0
fi

# Parse with jq to get tools (requires jq)
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not installed; please install jq to enable manifest parsing." >&2
  exit 0
fi

echo "$MANIFEST_JSON" | jq -r '.tools[]?.name' | while read -r tool; do
  SKILL_PATH="$OUT_DIR/claw_tool_${tool}.md"
  cat > "$SKILL_PATH" <<EOF
---
name: claw_tool_${tool}
description: Auto-generated wrapper for claw tool ${tool}
parameters:
  - name: args
    type: array
    description: Arguments to pass to the tool
---

Usage: This skill calls the Claw harness: `claw run-tool ${tool} --args ...`

# NOTE: Review generated skill for parameter types and adapt as needed.
EOF
  echo "Generated $SKILL_PATH"
done

echo "expose-claw-tools scaffold completed (dynamic skills generated in $OUT_DIR)."
