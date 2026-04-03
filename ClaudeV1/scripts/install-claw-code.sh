#!/usr/bin/env bash
# =============================================================================
# install-claw-code.sh — Build and install Claw-code Rust harness
#
# Clones ultraworkers/claw-code-parity (or uses local submodule),
# builds the Rust CLI, installs binary to /usr/local/bin/claw,
# and sets up the Axum server as a systemd service.
#
# USER INPUT REQUIRED:
#   CLAW_CODE_REPO — URL of the claw-code repo (or "local" to use submodule)
#   Default submodule path: /JakeClaw/claw-code
#
#   NOTE: Building Rust requires network access to crates.io on first build.
#         Subsequent builds use the cargo cache.
#
# Idempotent: checks for existing /usr/local/bin/claw before rebuilding.
# =============================================================================
set -euo pipefail
[[ "${EUID}" -ne 0 ]] && { echo "Must run as root" >&2; exit 1; }

JAKE_USER="${JAKE_USER:-jake}"
JAKE_HOME="${JAKE_HOME:-/home/${JAKE_USER}}"
JAKECLAW_DIR="${JAKECLAW_DIR:-/JakeClaw}"
CLAW_SRC="${JAKECLAW_DIR}/claw-code"

# USER INPUT OPTIONAL: override with your fork URL
CLAW_CODE_REPO="${CLAW_CODE_REPO:-https://github.com/ultraworkers/claw-code-parity.git}"

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [install-claw-code] $*"; }

# ── Source Rust environment ───────────────────────────────────────────────
export HOME="${JAKE_HOME}"
export PATH="${JAKE_HOME}/.cargo/bin:${PATH}"

# ── Ensure source is present ──────────────────────────────────────────────
if [[ ! -d "${CLAW_SRC}/.git" ]] && [[ ! -f "${CLAW_SRC}/Cargo.toml" ]]; then
  log "Cloning claw-code from ${CLAW_CODE_REPO}..."
  git clone "${CLAW_CODE_REPO}" "${CLAW_SRC}"
  chown -R "${JAKE_USER}:${JAKE_USER}" "${CLAW_SRC}"
else
  log "Claw-code source found at ${CLAW_SRC}"
fi

# ── Check if already installed and up to date ─────────────────────────────
INSTALLED_VERSION=""
if command -v claw >/dev/null 2>&1; then
  INSTALLED_VERSION=$(claw --version 2>/dev/null || echo "unknown")
  log "claw already installed: ${INSTALLED_VERSION}"
  # Rebuild if source has changed (check git hash)
  SRC_HASH=$(git -C "${CLAW_SRC}" rev-parse HEAD 2>/dev/null || echo "none")
  HASH_FILE="/var/lib/jake/claw-installed-hash"
  if [[ -f "$HASH_FILE" ]] && [[ "$(cat "$HASH_FILE")" == "$SRC_HASH" ]]; then
    log "Claw-code binary is up to date — skipping rebuild"
    exit 0
  fi
  log "Source hash changed — rebuilding claw-code"
fi

# ── Build ─────────────────────────────────────────────────────────────────
log "Building claw-code (this may take a few minutes)..."
mkdir -p /var/lib/jake

su - "${JAKE_USER}" -c "
  source ~/.cargo/env 2>/dev/null || true
  cd ${CLAW_SRC}
  # Build the CLI binary
  cargo build --release 2>&1
" || { log "ERROR: cargo build failed — check ${CLAW_SRC}" >&2; exit 1; }

# ── Install binary ────────────────────────────────────────────────────────
BINARY="${CLAW_SRC}/target/release/claw"
if [[ ! -f "$BINARY" ]]; then
  # Try alternate name
  BINARY=$(find "${CLAW_SRC}/target/release" -maxdepth 1 -type f -executable 2>/dev/null | head -1)
fi

if [[ -f "$BINARY" ]]; then
  # Keep backup of previous binary for rollback
  if [[ -f /usr/local/bin/claw ]]; then
    cp /usr/local/bin/claw /usr/local/bin/claw.bak
  fi
  cp "$BINARY" /usr/local/bin/claw
  chmod +x /usr/local/bin/claw
  log "Installed: $(claw --version)"
  # Record installed hash
  git -C "${CLAW_SRC}" rev-parse HEAD > /var/lib/jake/claw-installed-hash 2>/dev/null || true
else
  log "WARNING: No claw binary found after build. Check Cargo.toml for the correct binary name."
  log "         Placeholder 'claw' wrapper will be used until real binary is built."
  # ── Placeholder wrapper ──────────────────────────────────────────────
  # USER INPUT REQUIRED: replace this with the real binary once claw-code
  # repo is properly linked. This allows the rest of the bootstrap to proceed.
  cat > /usr/local/bin/claw << 'PLACEHOLDER'
#!/usr/bin/env bash
# PLACEHOLDER — replace with real claw binary from ultraworkers/claw-code-parity
# USER INPUT REQUIRED: build and install real claw binary
echo "[claw-placeholder] claw command: $*"
case "$1" in
  --version) echo "claw 0.0.0-placeholder" ;;
  manifest)  echo '{"tools":[]}' ;;
  *)         echo "[claw-placeholder] command '$1' not implemented in placeholder" >&2 ;;
esac
PLACEHOLDER
  chmod +x /usr/local/bin/claw
fi

# ── Systemd service for Claw-code Axum server (if applicable) ─────────────
# USER INPUT REQUIRED: update ExecStart if your claw-code server binary
# name or flags differ from the defaults below
cat > /etc/systemd/system/claw-code.service << EOF
[Unit]
Description=Claw-code Rust Harness Server
After=network.target

[Service]
Type=simple
User=${JAKE_USER}
WorkingDirectory=${CLAW_SRC}
# USER INPUT REQUIRED: adjust flags/port if claw-code server uses different args
ExecStart=/usr/local/bin/claw serve --port 8081
Restart=on-failure
RestartSec=5
Environment="HOME=${JAKE_HOME}"
Environment="PATH=${JAKE_HOME}/.cargo/bin:/usr/local/bin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable claw-code.service
# Start only if real binary is present (not placeholder)
if claw --version 2>/dev/null | grep -v placeholder; then
  systemctl start claw-code.service || log "Note: claw-code service start failed (may need configuration)"
fi

log "Claw-code installation complete"
