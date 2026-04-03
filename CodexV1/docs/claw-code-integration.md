# Claw-code Integration

## Goal

The repo treats Claw-code as a structured execution harness that complements, rather than replaces, OpenClaw.

## Current pattern

1. `scripts/install-claw-code.sh` clones and builds the harness, then installs `/usr/local/bin/claw`.
2. `scripts/setup-jake-api.sh` places a LiteLLM-based OpenAI-compatible wrapper on top of the local Claw service.
3. `skills/claw-harness/SKILL.md` gives Jake a stable interface for requesting harness actions.
4. `scripts/expose-claw-tools.sh` converts `claw manifest --format json` output into generated OpenClaw skill files.

## Build expectations

- The current script assumes `claw serve --host 127.0.0.1 --port 8081` exists in your harness build.
- If your actual upstream uses a different binary layout or server command, update `install-claw-code.sh` and `setup-jake-api.sh` together.
- The dynamic skill generator assumes the manifest emits a top-level `tools` array with JSON schema-like parameter metadata.

## Safe extension points

- Replace LiteLLM with a native OpenAI-compatible route if Claw-code already supports it.
- Add a service health endpoint and update `scripts/deploy-test.sh` to verify it.
- Generate richer skill metadata from the manifest once the schema is finalized.

## Recovery path

If a Claw-code rebuild fails during the self-improvement cycle, the worker restores the previous `claw` binary from `/usr/local/bin/claw.previous` if present.
