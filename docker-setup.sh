#!/bin/bash
# ================================================================
# Docker Installation Script (minimal + BuildKit + buildx)
# Fixes legacy builder deprecation for camofox-browser
# ================================================================

set -euo pipefail

echo "=== Docker Installation Script (with BuildKit + buildx) ==="

# Update package index
echo "→ Updating package index..."
sudo apt update

# Install Docker if not present
if ! command -v docker >/dev/null 2>&1; then
  echo "→ Installing Docker..."
  sudo apt install -y docker.io
else
  echo "→ Docker already installed."
fi

# Enable and start Docker service
sudo systemctl enable --now docker
echo "→ Docker service is active."

# === ENABLE BUILDKIT + INSTALL BUILDX PLUGIN ===
echo "→ Enabling Docker BuildKit and installing buildx plugin..."
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "features": {
    "buildkit": true
  }
}
EOF

sudo apt install -y docker-buildx-plugin

# Create and activate default buildx builder (removes legacy warning permanently)
echo "→ Setting up default buildx builder..."
docker buildx create --name default --use --bootstrap || true

# Restart Docker to apply everything
sudo systemctl restart docker
echo "→ Docker restarted with BuildKit + buildx enabled."

# Add current user to docker group
if ! groups | grep -q '\bdocker\b'; then
  sudo usermod -aG docker "$USER"
  echo "✅ Added $USER to docker group."
  echo "⚠️  IMPORTANT: Log out and back in (or reboot) for group change to take effect."
else
  echo "→ User already in docker group."
fi

echo ""
echo "================================================================"
echo "✅ Docker + BuildKit + buildx setup complete!"
echo "The legacy builder warning should now be gone."
echo "You can now re-run ./install-camofox.sh"
echo "================================================================"
