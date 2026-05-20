#!/bin/bash
set -euo pipefail

echo "=== Latest Docker Installation Script (Official + BuildKit + buildx) ==="

# Prerequisites
sudo apt update
sudo apt install -y ca-certificates curl

# Docker official repo
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update

# Install
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable service
sudo systemctl enable --now docker

# Enable BuildKit (usually default now, but explicit is fine)
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "features": {
    "buildkit": true
  }
}
EOF

# Create default builder
docker buildx create --name default --use --bootstrap || true

sudo systemctl restart docker

# Add user to docker group
if ! groups | grep -q '\bdocker\b'; then
  sudo usermod -aG docker "$USER"
  echo "✅ Added $USER to docker group. Log out/in or reboot."
fi

echo "================================================================"
echo "✅ Docker + BuildKit + buildx setup complete!"
echo "================================================================"
