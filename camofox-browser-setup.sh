#!/bin/bash
# ================================================================
# Camofox Setup & Repair Script for Hermes Agent VM
# - Auto-detects architecture (x86_64 or aarch64) like the official Makefile
# - Safe to run once for install, or again anytime to repair/update/restart
# ================================================================
set -euo pipefail

echo "=== Camofox Setup & Repair Script ==="

REPO_DIR="$HOME/camofox-browser"
CONTAINER_NAME="camofox-browser"
HERMES_ENV="$HOME/.hermes/.env"
HERMES_CONFIG="$HOME/.hermes/config.yaml"

# 1. Ensure repo exists and is up-to-date
if [ -d "$REPO_DIR/.git" ]; then
  echo "→ Repo exists — pulling latest..."
  cd "$REPO_DIR"
  git pull --ff-only
else
  echo "→ Cloning camofox-browser..."
  rm -rf "$REPO_DIR"
  git clone https://github.com/jo-inc/camofox-browser.git "$REPO_DIR"
  cd "$REPO_DIR"
fi

# 2. Auto-detect architecture
case "$(uname -m)" in
  x86_64|amd64)
    ARCH="x86_64"
    ;;
  aarch64|arm64)
    ARCH="aarch64"
    ;;
  *)
    echo "❌ Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

echo "→ Detected architecture: $ARCH"
IMAGE="camofox-browser:135.0.1-${ARCH}"

# 3. Fetch Camoufox binaries
echo "→ Fetching Camoufox binaries..."
make fetch

# 4. Build image if missing
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "→ Building Docker image: $IMAGE"
  make build
else
  echo "→ Image $IMAGE already exists."
fi

# 5. Create/refresh idempotent docker-run.sh
# IMPORTANT: This script must NOT force-remove a healthy running container.
# systemd may invoke it repeatedly; if the container is already running, it exits cleanly.
echo "→ Creating/refreshing docker-run.sh..."
cat > docker-run.sh <<EOF
#!/bin/bash
set -euo pipefail

mkdir -p "\$HOME/.camofox"
IMAGE="$IMAGE"
CONTAINER_NAME="$CONTAINER_NAME"

if docker ps --format '{{.Names}}' | grep -qx "\$CONTAINER_NAME"; then
  echo "\$CONTAINER_NAME already running; not recreating"
  exit 0
fi

if docker ps -a --format '{{.Names}}' | grep -qx "\$CONTAINER_NAME"; then
  echo "→ Removing stopped/stale \$CONTAINER_NAME container..."
  docker rm -f "\$CONTAINER_NAME" 2>/dev/null || true
fi

docker run -d \\
  --name "\$CONTAINER_NAME" \\
  --restart unless-stopped \\
  -p 9377:9377 \\
  -p 6080:6080 \\
  -p 5901:5900 \\
  -e CAMOFOX_PORT=9377 \\
  -e ENABLE_VNC=1 \\
  -e VNC_BIND=0.0.0.0 \\
  -e VNC_RESOLUTION=1920x1080 \\
  -e MAX_OLD_SPACE_SIZE=2048 \\
  -v "\$HOME/.camofox:/root/.camofox" \\
  "\$IMAGE"
EOF
chmod +x docker-run.sh

# 6. Start or ensure container is running
echo "→ Starting/ensuring Camofox container..."
./docker-run.sh

# 7. Install systemd service
# Use Type=oneshot because docker-run.sh starts a detached Docker container and exits.
# Docker's --restart unless-stopped policy manages the long-running container.
echo "→ Ensuring systemd service is installed..."
sudo tee /etc/systemd/system/camofox-browser.service > /dev/null <<EOF
[Unit]
Description=Camofox Browser Server for Hermes Agent
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
User=$USER
WorkingDirectory=$REPO_DIR
ExecStart=$REPO_DIR/docker-run.sh
ExecStop=/usr/bin/docker stop $CONTAINER_NAME
RemainAfterExit=yes
Restart=no
Environment="PATH=/usr/bin:/usr/local/bin:/usr/sbin"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl reset-failed camofox-browser.service || true
sudo systemctl enable --now camofox-browser.service

# 8. Health check
echo "→ Running health check..."
for i in {1..20}; do
  if curl -s -f http://localhost:9377/health >/dev/null 2>&1; then
    echo "✅ Camofox is healthy."
    break
  fi

  if [ "$i" -eq 20 ]; then
    echo "⚠️ Health check failed after waiting. Restarting container once..."
    docker restart "$CONTAINER_NAME" >/dev/null
    sleep 5
    curl -s -f http://localhost:9377/health >/dev/null
    echo "✅ Camofox is healthy after restart."
    break
  fi

  sleep 1
done

# 9. Hermes config
echo "→ Ensuring Hermes is configured..."
mkdir -p "$HOME/.hermes"
touch "$HERMES_ENV"

if grep -q '^CAMOFOX_URL=' "$HERMES_ENV"; then
  sed -i 's|^CAMOFOX_URL=.*|CAMOFOX_URL=http://localhost:9377|' "$HERMES_ENV"
else
  echo 'CAMOFOX_URL=http://localhost:9377' >> "$HERMES_ENV"
fi
echo "✅ Ensured CAMOFOX_URL in Hermes .env"

# Prefer Hermes' config writer if available; it avoids duplicate YAML keys.
if command -v hermes >/dev/null 2>&1; then
  hermes config set browser.camofox.managed_persistence true || true
else
  # Fallback: only create a minimal config if none exists. Avoid blindly appending
  # duplicate top-level browser: blocks to an existing YAML file.
  if [ ! -f "$HERMES_CONFIG" ]; then
    cat > "$HERMES_CONFIG" <<EOF
browser:
  camofox:
    managed_persistence: true
EOF
    echo "✅ Created Hermes config.yaml with managed persistence enabled"
  else
    echo "⚠️ Hermes CLI not found; please set browser.camofox.managed_persistence: true manually in $HERMES_CONFIG"
  fi
fi

# Restart gateway so CAMOFOX_URL/config changes are picked up.
if command -v hermes >/dev/null 2>&1; then
  hermes gateway restart || true
fi

# 10. Final status
echo ""
echo "================================================================"
echo "✅ CAMOFOX SETUP/REPAIR COMPLETE!"
echo "Architecture detected: $ARCH"
echo "Image used: $IMAGE"
echo "Container: $CONTAINER_NAME"
echo "Health: http://localhost:9377/health"
echo "VNC: http://localhost:6080/vnc.html"
echo ""
echo "Run this script again anytime to repair/update/restart."
echo "================================================================"
