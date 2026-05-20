#!/bin/bash
# ================================================================
# Docker Installation Script (minimal + BuildKit enabled)
# Required for camofox-browser (uses --mount in Dockerfile)
# ================================================================

set -euo pipefail

echo "=== Docker Installation Script (with BuildKit) ==="

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

# === ENABLE BUILDKIT (fixes the --mount error) ===
echo "→ Enabling Docker BuildKit (required by camofox-browser)..."
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "features": {
    "buildkit": true
  }
}
EOF

# Restart Docker to apply BuildKit config
sudo systemctl restart docker
echo "→ Docker restarted with BuildKit enabled."

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
echo "✅ Docker + BuildKit setup complete!"
echo "You can now run ./install-camofox.sh (it will succeed on 'make build')"
echo "================================================================"
