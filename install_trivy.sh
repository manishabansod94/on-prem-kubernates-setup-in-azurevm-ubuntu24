#!/bin/bash
set -e

echo "======================================"
echo " Installing Trivy – Ubuntu 24.04"
echo "======================================"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Run as root"
  exit 1
fi

# Update
apt update -y

# Install dependencies
apt install -y wget apt-transport-https gnupg lsb-release

# Add Trivy GPG key
wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor \
  | tee /usr/share/keyrings/trivy.gpg > /dev/null

# Add Trivy repository
echo \
  "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
  https://aquasecurity.github.io/trivy-repo/deb \
  $(lsb_release -sc) main" \
  > /etc/apt/sources.list.d/trivy.list

# Install Trivy
apt update -y
apt install -y trivy

# Verify
trivy --version

echo "======================================"
echo " Trivy Installed Successfully"
echo "======================================"
