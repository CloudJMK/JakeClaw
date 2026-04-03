#!/usr/bin/env bash
# =============================================================================
# expose-claw-tools.sh — Bridge Claw-code tools into OpenClaw as SKILL.md files
#
# Queries `claw manifest` to discover available tools, then generates a
# SKILL.md file for each tool in skills/claw-tools-dynamic/.
# Finally, triggers an OpenClaw skill reload so the new skills are live.
#
# Generated skills are ephemeral (gitignored) and are re-created on each run.
#
# Idempotent: removes old dynamic skills before regenerating.
# Must run as root (for systemctl reload) or as jake (for claw access).
# =============================================================================
set -euo pipefail

JAKE_USER="${JAKE_USER:-jake}"
JAKECLAW_DIR="${JAKECLAW_DIR:-/JakeClaw}"
JAKE_DATA="${JAKE_DATA:-/Jake-data}"
CLAW_BIN="${CLAW_BIN:-/usr/local/bin/claw}"
DYNAMIC_SKILLS_DIR="${JAKECLAW_DIR}/skills/claw-tools-dynamic"
LOG_FILE="${JAKE_DATA}/logs/expose-claw-tools.log"
OPENCLAW_RELOAD_URL="${OPENCLAW_RELOAD_URL:-http://localhost:9000/api/skills/reload}"

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [expose-claw-tools] $*" | tee -a "${LOG_FILE}"; }

mkdir -p "${JAKE_DATA}/logs" "${DYNAMIC_SKILLS_DIR}"

log "====== expose-claw-tools START ======"

# ── Check claw binary ──────────────────────────────────────────────────────
if [[ ! -x "${CLAW_BIN}" ]]; then
  log "ERROR: ${CLAW_BIN} not found or not executable — aborting"
  exit 1
fi

# ── Fetch manifest ─────────────────────────────────────────────────────────
log "Querying claw manifest..."
MANIFEST_JSON=""
MANIFEST_JSON=$(su - "${JAKE_USER}" -c "${CLAW_BIN} manifest --json 2>/dev/null" 2>/dev/null) || {
  # Try without --json flag (older claw versions)
  MANIFEST_JSON=$(su - "${JAKE_USER}" -c "${CLAW_BIN} manifest 2>/dev/null" 2>/dev/null) || {
    log "ERROR: claw manifest failed — OpenClaw skill reload skipped"
    log "       Is claw-code running? Check: systemctl status claw-code.service"
    exit 1
  }
}

log "Manifest received (${#MANIFEST_JSON} bytes)"

# ── Parse tool list ────────────────────────────────────────────────────────
# Handles both JSON array format and newline-delimited tool names
if echo "${MANIFEST_JSON}" | python3 -c "import sys,json; json.load(sys.stdin)" >/dev/null 2>&1; then
  # JSON format: [{name, description, parameters}...]
  TOOLS=$(echo "${MANIFEST_JSON}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, list):
    for t in data:
        name = t.get('name','')
        desc = t.get('description','No description.')
        params = t.get('parameters', {})
        print(name + '|||' + desc + '|||' + str(params))
elif isinstance(data, dict):
    tools = data.get('tools', [])
    for t in tools:
        name = t.get('name','')
        desc = t.get('description','No description.')
        params = t.get('parameters', {})
        print(name + '|||' + desc + '|||' + str(params))
")
else
  # Plain text: one tool name per line
  TOOLS=$(echo "${MANIFEST_JSON}" | while read -r line; do
    [[ -n "$line" ]] && echo "${line}|||Claw-code tool.|||{}"
  done)
fi

# ── Remove old dynamic skills ──────────────────────────────────────────────
log "Removing old dynamic skills from ${DYNAMIC_SKILLS_DIR}/"
find "${DYNAMIC_SKILLS_DIR}" -name "*.md" -not -name ".gitkeep" -delete 2>/dev/null || true

# ── Generate new SKILL.md files ───────────────────────────────────────────
TOOL_COUNT=0
while IFS='|||' read -r TOOL_NAME TOOL_DESC TOOL_PARAMS; do
  [[ -z "${TOOL_NAME}" ]] && continue

  # Sanitize name for filesystem
  SAFE_NAME="${TOOL_NAME//[^a-zA-Z0-9_-]/_}"
  SKILL_FILE="${DYNAMIC_SKILLS_DIR}/${SAFE_NAME}.md"

  cat > "${SKILL_FILE}" << EOF
---
name: claw_${SAFE_NAME}
description: >
  Claw-code tool: ${TOOL_NAME}. ${TOOL_DESC}
  (Auto-generated from claw manifest — do not edit; re-run expose-claw-tools.sh to refresh)
version: "auto"
parameters:
  args:
    type: array
    items:
      type: string
    required: false
    description: Arguments to pass to the tool.
  project_path:
    type: string
    required: false
    description: Working directory (optional).
---

# claw_${SAFE_NAME}

**Source**: Claw-code tool \`${TOOL_NAME}\`

${TOOL_DESC}

## Usage

Call via the \`claw_harness\` skill:

\`\`\`yaml
command: run-tool
args: ["${TOOL_NAME}", "--help"]
\`\`\`

Or directly via wrap-claw.sh:

\`\`\`bash
bash /JakeClaw/skills/claw-harness/tools/wrap-claw.sh run-tool ${TOOL_NAME} [args...]
\`\`\`

## Parameters

\`\`\`
${TOOL_PARAMS}
\`\`\`

_Auto-generated $(date '+%Y-%m-%dT%H:%M:%SZ'). Re-run expose-claw-tools.sh to refresh._
EOF

  TOOL_COUNT=$((TOOL_COUNT + 1))
  log "  Generated skill: claw_${SAFE_NAME}"
done <<< "${TOOLS}"

log "Generated ${TOOL_COUNT} dynamic skill(s)"

# ── Reload OpenClaw skill index ────────────────────────────────────────────
log "Requesting OpenClaw skill reload..."

# Attempt HTTP reload (if OpenClaw exposes a reload endpoint)
# USER INPUT: adjust OPENCLAW_RELOAD_URL if your OpenClaw version uses a different endpoint
if curl -sf -X POST "${OPENCLAW_RELOAD_URL}" \
    -H "Content-Type: application/json" \
    -d '{"action":"reload-skills"}' \
    -o /dev/null 2>/dev/null; then
  log "OpenClaw skills reloaded via HTTP endpoint"
else
  log "HTTP reload not available (endpoint: ${OPENCLAW_RELOAD_URL})"
  log "Skills will be picked up on next OpenClaw start/restart."
  log "Manual reload: send a 'reload skills' message to Jake in the Continue sidebar."
fi

log "====== expose-claw-tools END (${TOOL_COUNT} tools exposed) ======"
