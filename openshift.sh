USER-DATA SCRIPT
----------------------

#!/bin/bash

# Set ubuntu password
echo "ubuntu:Login%12345" | sudo chpasswd

# Find and replace ALL PasswordAuthentication no in /etc/ssh
sudo grep -Rl "PasswordAuthentication no" /etc/ssh | sudo xargs sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g'
sudo grep -Rl "#PasswordAuthentication no" /etc/ssh | sudo xargs sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/g'

# Ensure PAM is enabled
sudo sed -i 's/^#UsePAM no/UsePAM yes/' /etc/ssh/sshd_config
sudo sed -i 's/^UsePAM no/UsePAM yes/' /etc/ssh/sshd_config

# Restart SSH service

# ----------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------
# OPENLENS SCRIPT FOR CERT
# ----------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------

#!/bin/bash

set -e

echo "======================================"
echo "STEP 0: Fetching Public & Private IP"
echo "======================================"

# Public IP (fallback logic)
PUBLIC_IP=$(curl -s --max-time 3 ifconfig.me)

if [ -z "$PUBLIC_IP" ]; then
  echo "ifconfig.me failed, trying api.ipify.org..."
  PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org)
fi

if [ -z "$PUBLIC_IP" ]; then
  echo "ERROR: Unable to fetch Public IP"
  exit 1
fi

# Private IP
PRIVATE_IP=$(hostname -I | awk '{print $1}')

if [ -z "$PRIVATE_IP" ]; then
  echo "ERROR: Unable to fetch Private IP"
  exit 1
fi

echo "Public IP  : $PUBLIC_IP"
echo "Private IP : $PRIVATE_IP"

echo "======================================"
echo "STEP 1: Creating kubeadm config file"
echo "======================================"

cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
apiServer:
  certSANs:
  - "${PUBLIC_IP}"
  - "${PRIVATE_IP}"
  - "127.0.0.1"
  - "localhost"
  - "ip-${PRIVATE_IP}"
EOF

echo "kubeadm-config.yaml created:"
cat kubeadm-config.yaml

echo "======================================"
echo "STEP 2: Backup existing certificates"
echo "======================================"

sudo mkdir -p /etc/kubernetes/pki/backup

sudo mv /etc/kubernetes/pki/apiserver.key /etc/kubernetes/pki/backup/apiserver.key.bak 2>/dev/null || true
sudo mv /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/backup/apiserver.crt.bak 2>/dev/null || true

echo "Backup completed"

echo "======================================"
echo "STEP 3: Regenerating API Server Cert"
echo "======================================"

sudo kubeadm init phase certs apiserver --config kubeadm-config.yaml

echo "======================================"
echo "STEP 4: Validating Certificate SAN"
echo "======================================"

sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | grep -A1 "Subject Alternative Name"

echo "======================================"
echo "STEP 5: Restarting kubelet"
echo "======================================"

sudo systemctl restart kubelet

sleep 5

echo "Kubelet restarted successfully"

echo "======================================"
echo "FINAL STEP: Kubeconfig for OpenLens"
echo "======================================"

echo ""
echo "👉 Copy below kubeconfig:"
echo "--------------------------------------"
cat /root/.kube/config
echo "--------------------------------------"

echo ""
echo "👉 IMPORTANT:"
echo "1. Replace server IP in kubeconfig with PUBLIC IP: $PUBLIC_IP"
echo "2. Save file locally"
echo "3. Open OpenLens → Browse → Add Cluster → Load kubeconfig"
echo ""

echo "🎉 DONE: Your cluster is ready for external access!"
