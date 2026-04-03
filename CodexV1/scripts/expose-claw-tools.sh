#!/usr/bin/env bash
set -euo pipefail

FORCE=0
RELOAD=0
for arg in "$@"; do
  case "${arg}" in
    --force=1|--force) FORCE=1 ;;
    --reload) RELOAD=1 ;;
  esac
done

SKILL_DIR="${JAKE_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/skills/claw-tools-dynamic"
LOG_DIR="${JAKE_DATA_DIR:-/Jake-data}/logs"
LOG_FILE="${LOG_DIR}/expose-claw-tools.log"

mkdir -p "${SKILL_DIR}" "${LOG_DIR}"

if ! command -v claw >/dev/null 2>&1; then
  echo "claw binary not found; cannot generate dynamic skills." | tee -a "${LOG_FILE}"
  exit 0
fi

MANIFEST_JSON="$(mktemp)"
if ! claw manifest --format json > "${MANIFEST_JSON}" 2>> "${LOG_FILE}"; then
  echo "claw manifest failed; skipping reload." | tee -a "${LOG_FILE}"
  rm -f "${MANIFEST_JSON}"
  exit 0
fi

find "${SKILL_DIR}" -maxdepth 1 -type f -name '*.md' -delete

python3 - "${MANIFEST_JSON}" "${SKILL_DIR}" <<'PY'
import json
import pathlib
import re
import sys

manifest_path = pathlib.Path(sys.argv[1])
out_dir = pathlib.Path(sys.argv[2])
data = json.loads(manifest_path.read_text())
tools = data.get("tools", [])

for tool in tools:
    raw_name = tool.get("name", "unnamed-tool")
    file_stub = re.sub(r"[^a-zA-Z0-9._-]+", "-", raw_name).strip("-") or "tool"
    description = tool.get("description", "Dynamically generated Claw tool.")
    params = tool.get("parameters", {})
    required = params.get("required", [])
    properties = params.get("properties", {})

    lines = [
        "---",
        f"name: {raw_name}",
        f"description: {description}",
        "parameters:",
    ]

    if not properties:
        lines.append("  raw_args:")
        lines.append("    type: string")
        lines.append("    description: Raw argument string for the generated tool.")
    else:
        for key, meta in properties.items():
            lines.append(f"  {key}:")
            lines.append(f"    type: {meta.get('type', 'string')}")
            desc = meta.get("description", "No description provided.")
            lines.append(f"    description: {desc}")

    if required:
        lines.append("required:")
        for item in required:
            lines.append(f"  - {item}")

    lines.extend(
        [
            "---",
            "",
            f"# {raw_name}",
            "",
            description,
            "",
            "This file is generated from `claw manifest --format json`.",
        ]
    )

    (out_dir / f"{file_stub}.md").write_text("\n".join(lines) + "\n")
PY

rm -f "${MANIFEST_JSON}"
touch "${SKILL_DIR}/.gitkeep"

if [[ "${RELOAD}" -eq 1 ]]; then
  if [[ "${FORCE}" -ne 1 ]]; then
    read -r -p "Reload OpenClaw skills now? [y/N] " reply
    [[ "${reply}" =~ ^[Yy]$ ]] || exit 0
  fi

  if [[ -n "${OPENCLAW_RELOAD_URL:-}" ]]; then
    curl -fsS -X POST \
      -H "Authorization: Bearer ${OPENCLAW_RELOAD_TOKEN:-}" \
      "${OPENCLAW_RELOAD_URL}" >> "${LOG_FILE}" 2>&1 || {
        echo "OpenClaw reload failed" | tee -a "${LOG_FILE}"
        exit 0
      }
  fi
fi
