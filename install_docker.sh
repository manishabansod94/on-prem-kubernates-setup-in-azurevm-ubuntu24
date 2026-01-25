#!/bin/bash
set -e

echo "======================================"
echo " Installing Docker – Ubuntu 24.04"
echo "======================================"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Run as root"
  exit 1
fi

# Update system
apt update -y

# Install prerequisites
apt install -y ca-certificates curl gnupg

# Create keyrings directory
install -m 0755 -d /etc/apt/keyrings

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

# Install Docker
apt update -y
apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable Docker
systemctl enable docker
systemctl start docker

# Allow Jenkins to use Docker
usermod -aG docker jenkins

echo "======================================"
echo " Docker Installed Successfully"
echo " Log out & login required for group changes"
echo "======================================"
