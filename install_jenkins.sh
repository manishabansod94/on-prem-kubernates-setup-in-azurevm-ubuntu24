#!/bin/bash
set -e

echo "======================================"
echo " Jenkins APT Install – Ubuntu 24.04"
echo " (trusted=yes workaround)"
echo "======================================"

# Root check
[ "$EUID" -ne 0 ] && echo "Run as root" && exit 1

# Clean old Jenkins stuff
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /usr/share/keyrings/jenkins*

# Base update
apt update -y
apt install -y openjdk-17-jre-headless curl ca-certificates

# Add Jenkins repo (APT TRUST BYPASS)
echo "deb [trusted=yes] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

# Update (THIS WILL NOW WORK)
apt update -y

# Install Jenkins
apt install -y jenkins

# Start Jenkins
systemctl enable jenkins
systemctl start jenkins

echo "======================================"
echo " Jenkins Installed (APT trusted mode)"
echo " URL: http://<VM_PUBLIC_IP>:8080"
echo " Password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo "======================================"
