#!/bin/bash
# ================================================================
# Camofox Installation Script for Hermes Agent VM
# - Assumes Docker is already installed
# - Clones, builds, sets up persistence + VNC + systemd auto-start
# - Idempotent (safe to re-run for upgrades)
# ================================================================

set -euo pipefail

echo "=== Camofox Installation Script ==="

REPO_DIR="$HOME/camofox-browser"

# 1. Clone / update repo
if [ -d "$REPO_DIR" ]; then
  echo "→ Repo exists, pulling latest..."
  cd "$REPO_DIR"
  git pull --ff-only
else
  echo "→ Cloning camofox-browser..."
  git clone https://github.com/jo-inc/camofox-browser.git "$REPO_DIR"
  cd "$REPO_DIR"
fi

# 2. Fetch + build (official process)
echo "→ Fetching Camoufox binaries..."
make fetch

echo "→ Building Docker image..."
make build

# 3. Enhanced docker-run.sh (persistence + VNC)
echo "→ Creating docker-run.sh with profile persistence + VNC..."
cat > docker-run.sh << 'EOF'
#!/bin/bash
mkdir -p ~/.camofox

IMAGE="camofox-browser:135.0.1-x86_64"

docker stop camofox-browser 2>/dev/null || true
docker rm camofox-browser 2>/dev/null || true

docker run -d \
  --name camofox-browser \
  --restart unless-stopped \
  -p 9377:9377 \
  -p 6080:6080 \
  -p 5901:5900 \
  -e ENABLE_VNC=1 \
  -e VNC_BIND=0.0.0.0 \
  -e VNC_RESOLUTION=1920x1080 \
  -e MAX_OLD_SPACE_SIZE=2048 \
  -v ~/.camofox:/root/.camofox \
  "${IMAGE}"
EOF

chmod +x docker-run.sh

# 4. Start container
echo "→ Starting Camofox container..."
./docker-run.sh

# 5. Systemd service (true boot auto-start)
echo "→ Installing systemd service..."
sudo tee /etc/systemd/system/camofox-browser.service > /dev/null <<EOF
[Unit]
Description=Camofox Browser Server for Hermes Agent
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/camofox-browser
ExecStart=$HOME/camofox-browser/docker-run.sh
Restart=always
RestartSec=10
Environment="PATH=/usr/bin:/usr/local/bin:/usr/sbin"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now camofox-browser.service

# 6. Hermes config
echo "→ Configuring Hermes..."
HERMES_ENV="$HOME/.hermes/.env"
mkdir -p "$HOME/.hermes"
if [ -f "$HERMES_ENV" ] && grep -q "^CAMOFOX_URL=" "$HERMES_ENV" 2>/dev/null; then
  echo "CAMOFOX_URL already configured."
else
  echo "CAMOFOX_URL=http://localhost:9377" >> "$HERMES_ENV"
  echo "✅ Added CAMOFOX_URL to Hermes .env"
fi

# Restart Hermes if possible
if command -v hermes >/dev/null 2>&1; then
  hermes gateway restart || true
fi

# 7. Final status
echo ""
echo "================================================================"
echo "✅ CAMOFOX INSTALLED & CONFIGURED!"
echo "Auto-starts on boot via systemd."
echo ""
echo "Verify:"
echo "  docker ps | grep camofox"
echo "  curl -I http://localhost:9377/health"
echo "  journalctl -u camofox-browser -f"
echo ""
echo "Live view: http://YOUR-VM-IP:6080"
echo "================================================================"
