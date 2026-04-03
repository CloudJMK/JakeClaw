#!/usr/bin/env bash
set -euo pipefail

# Creates systemd service and timer files for Jake self-improvement loop.
SERVICE_PATH="/etc/systemd/system/jake-self-improve.service"
TIMER_PATH="/etc/systemd/system/jake-self-improve.timer"
WORKER_PATH="/usr/local/bin/jake-self-improve.sh"

cat > /tmp/jake-self-improve.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG_DIR=/Jake-data/logs
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/self-improve-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Basic self-improve steps (non-destructive):
# 1. git pull (no force)
# 2. build claw-code
# 3. run expose-claw-tools.sh to regenerate skills

cd /JakeClaw || exit 0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git diff --quiet || [ -z "$(git status --porcelain)" ]; then
    git pull origin main || { echo "git pull failed"; exit 1; }
  else
    echo "Local changes present; skipping automatic git pull."
    exit 0
  fi
fi

# Rebuild claw-code if present
if [ -d "claw-code/rust" ]; then
  pushd claw-code/rust >/dev/null
  cargo build --release || { echo "claw build failed"; popd >/dev/null; exit 1; }
  popd >/dev/null
fi

# Call expose script if present
if [ -f "/JakeClaw/GPTv1/scripts/expose-claw-tools.sh" ]; then
  bash /JakeClaw/GPTv1/scripts/expose-claw-tools.sh || echo "expose-claw-tools failed"
fi

echo "Self-improvement run complete"
EOF

mv /tmp/jake-self-improve.sh "$WORKER_PATH" || true
chmod +x "$WORKER_PATH" || true

cat > /tmp/jake-self-improve.service <<'EOF'
[Unit]
Description=Jake Self-Improvement Worker
After=network.target

[Service]
Type=oneshot
User=${JAKE_USER:-jake}
ExecStart=/usr/local/bin/jake-self-improve.sh

[Install]
WantedBy=multi-user.target
EOF

cat > /tmp/jake-self-improve.timer <<'EOF'
[Unit]
Description=Runs Jake self-improvement periodically

[Timer]
OnBootSec=15min
OnUnitActiveSec=6h
Unit=jake-self-improve.service

[Install]
WantedBy=timers.target
EOF

mv /tmp/jake-self-improve.service "$SERVICE_PATH" || true
mv /tmp/jake-self-improve.timer "$TIMER_PATH" || true
systemctl daemon-reload || true

echo "Scaffolded systemd service+timer and worker script (paths: $WORKER_PATH, $SERVICE_PATH, $TIMER_PATH). Review before enabling."
