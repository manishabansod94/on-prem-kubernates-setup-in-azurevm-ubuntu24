#!/bin/bash
set -e

echo "======================================"
echo " SonarQube Docker Setup"
echo " Ubuntu Server (22/24)"
echo "======================================"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root"
  exit 1
fi

# -------------------------
# Check Docker
# -------------------------
if command -v docker &>/dev/null; then
  echo "✅ Docker already installed"
else
  echo "🚀 Docker not found. Installing Docker..."

  apt-get update -y
  apt-get install -y ca-certificates curl gnupg

  install -m 0755 -d /etc/apt/keyrings

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable docker
  systemctl start docker

  echo "✅ Docker installed successfully"
fi

# -------------------------
# Verify Docker
# -------------------------
docker --version

# -------------------------
# SonarQube Setup
# -------------------------
echo "🚀 Setting up SonarQube..."

# Create persistent directories
mkdir -p /opt/sonarqube/{data,extensions,logs}

# 🔴 🔴 🔴 THIS IS THE CRITICAL FIX 🔴 🔴 🔴
# SonarQube runs as UID 1000 inside the container
chown -R 1000:1000 /opt/sonarqube
chmod -R 775 /opt/sonarqube
# 🔴 🔴 🔴 END OF FIX 🔴 🔴 🔴

# Remove existing container if exists
if docker ps -a | grep -q sonar; then
  echo "⚠ Existing SonarQube container found. Replacing it..."
  docker rm -f sonar
fi

# Run SonarQube container
docker run -d \
  --name sonar \
  -p 9000:9000 \
  -v /opt/sonarqube/data:/opt/sonarqube/data \
  -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
  -v /opt/sonarqube/logs:/opt/sonarqube/logs \
  --restart unless-stopped \
  sonarqube:lts-community

echo "======================================"
echo " ✅ SonarQube Installed Successfully"
echo " URL: http://<VM_IP>:9000"
echo
echo " Default Login:"
echo "   Username: admin"
echo "   Password: admin"
echo
echo " ⚠ You will be prompted to change password on first login"
echo "======================================"
