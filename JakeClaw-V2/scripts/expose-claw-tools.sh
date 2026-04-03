#!/usr/bin/env bash
# expose-claw-tools.sh — Generate SKILL.md files from claw-code tool manifest
#
# Queries the claw binary for its tool manifest, then creates one SKILL.md
# per tool in skills/claw-tools-dynamic/. Called by bootstrap and the
# self-improvement timer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi  # shellcheck source=/dev/null

JAKE_USER="${JAKE_USER:-jake}"
JAKE_DATA_DIR="${JAKE_DATA_DIR:-/Jake-data}"
CLAW_BIN="${CLAW_BIN:-/usr/local/bin/claw}"
OPENCLAW_RELOAD_URL="${OPENCLAW_RELOAD_URL:-http://localhost:3000/admin/reload}"
OPENCLAW_RELOAD_TOKEN="${OPENCLAW_RELOAD_TOKEN:-}"

SKILLS_OUT="${REPO_DIR}/skills/claw-tools-dynamic"
LOG_FILE="${JAKE_DATA_DIR}/logs/self-improvement.log"

mkdir -p "$SKILLS_OUT"
mkdir -p "${JAKE_DATA_DIR}/logs"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] expose-claw-tools: $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

log "Starting — output dir: ${SKILLS_OUT}"

# ---------------------------------------------------------------------------
# Query manifest
# ---------------------------------------------------------------------------
if [[ ! -x "$CLAW_BIN" ]]; then
  log "ERROR: claw binary not found at ${CLAW_BIN}"
  exit 1
fi

MANIFEST_JSON=""

# Try --json flag first, fall back to plain text
if MANIFEST_JSON=$("$CLAW_BIN" manifest --json 2>/dev/null); then
  log "Got JSON manifest"
elif MANIFEST_RAW=$("$CLAW_BIN" manifest 2>/dev/null); then
  log "Got plain-text manifest — converting to JSON"
  # Build a simple JSON array from one-tool-per-line output
  MANIFEST_JSON="["
  FIRST=true
  while IFS= read -r line; do
    TOOL_NAME=$(echo "$line" | tr -s ' ' | cut -d' ' -f1 | tr -dc '[:alnum:]_-')
    [[ -z "$TOOL_NAME" ]] && continue
    if [[ "$FIRST" == "true" ]]; then
      FIRST=false
    else
      MANIFEST_JSON+=","
    fi
    MANIFEST_JSON+="{\"name\":\"${TOOL_NAME}\",\"description\":\"${line}\"}"
  done <<< "$MANIFEST_RAW"
  MANIFEST_JSON+="]"
else
  log "ERROR: claw manifest failed — skipping skill generation"
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse tool list using Python (more robust than jq for both array/dict forms)
# ---------------------------------------------------------------------------
TOOL_NAMES=$(python3 - "$MANIFEST_JSON" << 'PYEOF'
import sys, json
raw = sys.argv[1]
data = json.loads(raw)
if isinstance(data, list):
    for item in data:
        name = item.get("name") or item.get("tool") or str(item)
        print(name)
elif isinstance(data, dict):
    for name in data.keys():
        print(name)
PYEOF
) || { log "ERROR: Failed to parse manifest JSON"; exit 1; }

if [[ -z "$TOOL_NAMES" ]]; then
  log "No tools found in manifest — nothing to generate"
  exit 0
fi

# ---------------------------------------------------------------------------
# Remove stale generated skills
# ---------------------------------------------------------------------------
find "$SKILLS_OUT" -name "SKILL.md" -delete 2>/dev/null || true

# ---------------------------------------------------------------------------
# Generate one SKILL.md per tool
# ---------------------------------------------------------------------------
COUNT=0
while IFS= read -r TOOL_NAME; do
  [[ -z "$TOOL_NAME" ]] && continue

  # Sanitize to safe directory name
  SAFE_NAME=$(echo "$TOOL_NAME" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]_' '_' | sed 's/_*$//')
  TOOL_DIR="${SKILLS_OUT}/${SAFE_NAME}"
  mkdir -p "$TOOL_DIR"

  cat > "${TOOL_DIR}/SKILL.md" << EOF
---
name: claw_${SAFE_NAME}
version: auto
generated_by: expose-claw-tools.sh
generated_at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
---

# Skill: claw_${SAFE_NAME}

Exposes the **${TOOL_NAME}** tool from claw-code.

## Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| args | array | no | Arguments to pass to the tool |
| project_path | string | no | Working directory for the command |

## Usage

Invoke via the \`claw_harness\` skill or directly through wrap-claw.sh:

\`\`\`yaml
skill: claw_harness
command: ${TOOL_NAME}
args: []
project_path: /Jake-data/workspace
\`\`\`

## Notes

- This file is auto-generated. Do not edit manually.
- Re-generate with: \`bash /JakeClaw/scripts/expose-claw-tools.sh\`
EOF

  COUNT=$((COUNT + 1))
done <<< "$TOOL_NAMES"

log "Generated ${COUNT} skill files in ${SKILLS_OUT}"

# ---------------------------------------------------------------------------
# Notify OpenClaw to reload skills
# ---------------------------------------------------------------------------
if [[ -n "$OPENCLAW_RELOAD_TOKEN" ]]; then
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$OPENCLAW_RELOAD_URL" \
    -H "Authorization: Bearer ${OPENCLAW_RELOAD_TOKEN}" \
    --connect-timeout 5 2>/dev/null || echo "000")

  if [[ "$HTTP_STATUS" == "200" ]]; then
    log "OpenClaw reloaded successfully"
  else
    log "WARNING: OpenClaw reload returned HTTP ${HTTP_STATUS} — reload manually or wait for next start"
  fi
else
  log "OPENCLAW_RELOAD_TOKEN not set — skills will be picked up on next OpenClaw restart"
fi

log "Done"
