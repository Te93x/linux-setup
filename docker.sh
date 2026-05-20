#!/bin/bash
# ================================================================
# Docker Installation Script (minimal & idempotent)
# For Hermes Agent VM — Ubuntu/Debian based
# ================================================================

set -euo pipefail

echo "=== Docker Installation Script ==="

# Update system
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
echo "✅ Docker setup complete!"
echo "================================================================"
