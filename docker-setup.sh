#!/bin/bash
set -euo pipefail

echo "=== Latest Docker Installation Script (Docker Engine + Compose + Buildx) ==="

# Update package index
sudo apt update

# Install prerequisites
sudo apt install -y ca-certificates curl

# Add Docker’s official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update

# === Install Docker Engine + Compose + Buildx ===
sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Enable and start Docker service
sudo systemctl enable --now docker

# Create default buildx builder (BuildKit is enabled by default)
docker buildx create --name default --use --bootstrap || true

# Add current user to docker group (so you don't need sudo)
if ! groups | grep -q '\bdocker\b'; then
    sudo usermod -aG docker "$USER"
    echo "✅ Added $USER to the docker group."
    echo "👉 Apply changes by running:   newgrp docker"
    echo "   (or log out and log back in)"
fi

echo "================================================================"
echo "✅ Docker Engine + Docker Compose + Buildx installed successfully!"
echo "================================================================"
echo "Test with:"
echo "   docker version"
echo "   docker compose version"
echo "   docker buildx version"
