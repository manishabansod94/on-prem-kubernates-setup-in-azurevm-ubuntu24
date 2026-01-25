#!/bin/bash
set -e

echo "======================================"
echo " Docker & Nexus Setup – Ubuntu 24.04"
echo "======================================"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Run this script as root"
  exit 1
fi

# -------------------------
# Update system
# -------------------------
apt-get update -y

# -------------------------
# Install dependencies
# -------------------------
apt-get install -y ca-certificates curl gnupg

# -------------------------
# Create keyrings directory
# -------------------------
install -m 0755 -d /etc/apt/keyrings

# -------------------------
# Add Docker GPG key
# -------------------------
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

# -------------------------
# Add Docker repository
# -------------------------
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
> /etc/apt/sources.list.d/docker.list

# -------------------------
# Install Docker
# -------------------------
apt-get update -y
apt-get install -y \
docker-ce \
docker-ce-cli \
containerd.io \
docker-buildx-plugin \
docker-compose-plugin

# -------------------------
# Enable & start Docker
# -------------------------
systemctl enable docker
systemctl start docker

# -------------------------
# Verify Docker
# -------------------------
docker --version

# -------------------------
# Setup Nexus
# -------------------------
echo "🚀 Setting up Nexus Repository..."

# Create Nexus data directory
mkdir -p /opt/nexus-data
chown -R 200:200 /opt/nexus-data

# Remove existing container if exists
if docker ps -a | grep -q nexus; then
  docker rm -f nexus
fi

# Run Nexus container
docker run -d \
  --name nexus \
  -p 8081:8081 \
  -v /opt/nexus-data:/nexus-data \
  --restart unless-stopped \
  sonatype/nexus3:latest

echo "======================================"
echo " ✅ Nexus Installed Successfully"
echo " URL: http://<SERVER_IP>:8081"
echo
echo " 🔑 Initial Admin Password:"
cat /opt/nexus-data/admin.password
echo "======================================"
