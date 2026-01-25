#!/bin/bash
set -Eeuo pipefail

echo "======================================"
echo " SonarQube Docker Setup (Self-Healing)"
echo "======================================"

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "❌ Run this script as root"
  exit 1
fi

# -------------------------
# Check Docker
# -------------------------
if ! command -v docker &>/dev/null; then
  echo "❌ Docker not found. Install Docker first."
  exit 1
fi

# -------------------------
# Kernel tuning (AUTO-FIX)
# -------------------------
echo "🔧 Checking vm.max_map_count..."

CURRENT_MAP_COUNT=$(sysctl -n vm.max_map_count)

if [ "$CURRENT_MAP_COUNT" -lt 262144 ]; then
  echo "⚠ vm.max_map_count too low ($CURRENT_MAP_COUNT). Fixing..."
  sysctl -w vm.max_map_count=262144

  if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
  fi

  sysctl -p
else
  echo "✅ vm.max_map_count is OK ($CURRENT_MAP_COUNT)"
fi

# -------------------------
# Memory check (WARN ONLY)
# -------------------------
TOTAL_MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')

echo "🔍 Total Memory: ${TOTAL_MEM_MB} MB"

if [ "$TOTAL_MEM_MB" -lt 2048 ]; then
  echo "⚠ WARNING: Less than 2GB RAM detected"
  echo "⚠ SonarQube may restart or perform poorly"
fi

# -------------------------
# SonarQube directories
# -------------------------
mkdir -p /opt/sonarqube/{data,extensions,logs}

# -------------------------
# Remove existing container
# -------------------------
if docker ps -a | grep -q sonar; then
  echo "🔁 Removing existing SonarQube container..."
  docker rm -f sonar
fi

# -------------------------
# Run SonarQube
# -------------------------
echo "🚀 Starting SonarQube container..."

docker run -d \
  --name sonar \
  -p 9000:9000 \
  -v /opt/sonarqube/data:/opt/sonarqube/data \
  -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
  -v /opt/sonarqube/logs:/opt/sonarqube/logs \
  --restart unless-stopped \
  sonarqube:lts-community

# -------------------------
# Health check loop
# -------------------------
echo "⏳ Waiting for SonarQube to become healthy..."

for i in {1..30}; do
  STATUS=$(docker inspect --format='{{.State.Status}}' sonar)
  if [ "$STATUS" = "running" ]; then
    echo "✅ SonarQube container is running"
    break
  fi
  sleep 10
done

# -------------------------
# Final verification
# -------------------------
STATUS=$(docker inspect --format='{{.State.Status}}' sonar)

if [ "$STATUS" != "running" ]; then
  echo "❌ SonarQube is still failing. Showing logs:"
  docker logs sonar | tail -50
  exit 1
fi

echo "======================================"
echo " ✅ SonarQube Setup Completed"
echo " URL: http://<VM_IP>:9000"
echo " Login: admin / admin"
echo "======================================"
