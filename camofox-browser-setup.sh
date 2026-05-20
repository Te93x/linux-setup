#!/bin/bash
# ================================================================
# Camofox Setup & Repair Script for Hermes Agent VM
# - Auto-detects architecture (x86_64 or aarch64) exactly like the official Makefile
# - Run once for install, run again anytime to repair/update/restart
# ================================================================
set -euo pipefail
echo "=== Latest Camofox Setup & Repair Script ==="
REPO_DIR="$HOME/camofox-browser"
# 1. Ensure repo exists and is up-to-date
if [ -d "$REPO_DIR" ]; then
  echo "→ Repo exists — pulling latest..."
  cd "$REPO_DIR"
  git pull --ff-only
else
  echo "→ Cloning camofox-browser..."
  git clone https://github.com/jo-inc/camofox-browser.git "$REPO_DIR"
  cd "$REPO_DIR"
fi
# 2. Auto-detect architecture (matches official Makefile logic)
ARCH=$(uname -m | sed 's/x86_64/x86_64/;s/aarch64/aarch64/;s/arm64/aarch64/')
echo "→ Detected architecture: $ARCH"
# 3. Fetch latest binaries
echo "→ Fetching Camoufox binaries..."
make fetch
# 4. Build image if missing
if ! docker image inspect "camofox-browser:135.0.1-${ARCH}" >/dev/null 2>&1; then
  echo "→ Building Docker image for $ARCH..."
  make build
else
  echo "→ Image camofox-browser:135.0.1-${ARCH} already exists."
fi
# 5. Create/refresh docker-run.sh with dynamic IMAGE (auto-detect)
echo "→ Creating/refreshing docker-run.sh with auto-detected architecture..."
cat > docker-run.sh << EOF
#!/bin/bash
mkdir -p ~/.camofox
# Dynamic image based on detected architecture
IMAGE="camofox-browser:135.0.1-\${ARCH}"

# Clean old container — use -f so it works even if container is running or restarting
docker rm -f camofox-browser 2>/dev/null || true

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
  "\${IMAGE}"
EOF
chmod +x docker-run.sh
# 6. (Re)start the container
echo "→ (Re)starting Camofox container..."
./docker-run.sh
# 7. Systemd service (unchanged — still perfect)
echo "→ Ensuring systemd service is installed..."
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
# 8. Health check
echo "→ Running health check..."
if curl -s -f http://localhost:9377/health >/dev/null 2>&1; then
  echo "✅ Camofox is healthy."
else
  echo "⚠️ Health check failed — restarting..."
  sudo systemctl restart camofox-browser.service
fi
# 9. Hermes config (.env + config.yaml) — forces managed_persistence: true
#    without touching ANY other keys or values
echo "→ Ensuring Hermes is configured..."
HERMES_ENV="$HOME/.hermes/.env"
HERMES_CONFIG="$HOME/.hermes/config.yaml"
mkdir -p "$HOME/.hermes"

# .env (unchanged)
if ! grep -q "^CAMOFOX_URL=" "$HERMES_ENV" 2>/dev/null; then
  echo "CAMOFOX_URL=http://localhost:9377" >> "$HERMES_ENV"
  echo "✅ Added CAMOFOX_URL to Hermes .env"
fi

# config.yaml — smart update (handles your exact case)
if [ ! -f "$HERMES_CONFIG" ]; then
  # Brand new file
  cat > "$HERMES_CONFIG" << EOF
browser:
  camofox:
    managed_persistence: true
EOF
  echo "✅ Created Hermes config.yaml with browser.camofox.managed_persistence: true"
else
  if grep -q "managed_persistence:" "$HERMES_CONFIG" 2>/dev/null; then
    # Key already exists (even if it was false) → update value only
    sed -i 's/^\([[:space:]]*\)managed_persistence: .*/\1managed_persistence: true/' "$HERMES_CONFIG"
    echo "✅ Updated browser.camofox.managed_persistence → true (preserved all other settings)"
  else
    # Key does not exist yet → append clean block at the end
    cat >> "$HERMES_CONFIG" << EOF

browser:
  camofox:
    managed_persistence: true
EOF
    echo "✅ Added browser.camofox.managed_persistence: true to Hermes config.yaml"
  fi
fi

if command -v hermes >/dev/null 2>&1; then
  hermes gateway restart || true
fi
# 10. Final status
echo ""
echo "================================================================"
echo "✅ CAMOFOX SETUP/REPAIR COMPLETE!"
echo "Architecture detected: $ARCH"
echo "Image used: camofox-browser:135.0.1-${ARCH}"
echo ""
echo "Run this script again anytime to repair/update/restart."
echo "================================================================"
