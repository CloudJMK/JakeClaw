#!/usr/bin/env bash
set -euo pipefail

REPO=${CLAW_CODE_REPO:-"https://github.com/ultraworkers/claw-code-parity.git"}
DEST=/opt/claw-code

if [ -d "$DEST" ]; then
  echo "claw-code already present at $DEST"
else
  echo "Cloning Claw-code from $REPO"
  git clone "$REPO" "$DEST" || exit 1
fi

# Ensure Rust toolchain
if ! command -v cargo >/dev/null 2>&1; then
  echo "Rust not found: installing rustup (user: $JAKE_USER)"
  # Non-interactive rustup install for root (may require adaptation)
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source $HOME/.cargo/env
fi

# Build the Rust CLI if present
if [ -d "$DEST/rust" ]; then
  pushd "$DEST/rust"
  cargo build --release || { echo "cargo build failed"; exit 1; }
  # Symlink binary if exists
  if [ -f "target/release/claw" ]; then
    ln -sf "$(pwd)/target/release/claw" /usr/local/bin/claw
  fi
  popd
fi

echo "Claw-code install complete. Verify with: claw --version"
