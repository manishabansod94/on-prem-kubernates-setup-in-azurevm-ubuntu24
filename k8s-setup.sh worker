#!/bin/bash
set -e

ROLE="$1"
AUTHOR="nishantminj"
POD_CIDR="10.244.0.0/16"
K8S_VERSION="v1.30"

if [[ -z "$ROLE" ]]; then
  echo "Usage: $0 {master|worker}"
  exit 1
fi

echo "=============================================="
echo " Kubernetes Setup Script"
echo " Author     : $AUTHOR"
echo " Role       : $ROLE"
echo " OS         : $(lsb_release -ds)"
echo " Date       : $(date)"
echo "=============================================="

CPU_COUNT=$(nproc)

if [[ "$CPU_COUNT" -lt 2 ]]; then
  echo "⚠️ WARNING: CPU count is $CPU_COUNT (<2)"
  if [[ "$IGNORE_CPU_CHECK" == "true" ]]; then
    echo "⚠️ Ignoring CPU preflight check"
    IGNORE_CPU_FLAG="--ignore-preflight-errors=NumCPU"
  else
    echo "❌ Kubernetes requires at least 2 vCPU"
    echo "👉 Resize VM or re-run with:"
    echo "   IGNORE_CPU_CHECK=true $0 $ROLE"
    exit 1
  fi
fi

echo "👉 Updating system"
sudo apt-get update -y
sudo apt-get install -y apt-transport-https curl ca-certificates gnupg lsb-release

echo "👉 Disabling swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "👉 Enabling kernel modules"
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/k8s.conf >/dev/null <<EOF
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sudo sysctl --system

echo "👉 Installing containerd"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
 | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
| sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update -y
sudo apt-get install -y containerd.io

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "👉 Installing Kubernetes ($K8S_VERSION)"
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key \
 | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

if [[ "$ROLE" == "master" ]]; then
  echo "👉 Initializing Kubernetes MASTER"
  sudo kubeadm init \
    --pod-network-cidr=$POD_CIDR \
    $IGNORE_CPU_FLAG

  mkdir -p $HOME/.kube
  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  echo "👉 Installing Flannel CNI"
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

  echo "👉 Generating join command"
  kubeadm token create --print-join-command | tee join-command.sh

  echo "=============================================="
  echo " MASTER SETUP COMPLETE"
  echo " Copy join-command.sh to worker nodes"
  echo "=============================================="

elif [[ "$ROLE" == "worker" ]]; then
  echo "=============================================="
  echo " WORKER NODE READY"
  echo " Run the join command from master:"
  echo
  echo " sudo kubeadm join <MASTER-IP>:6443 --token <token> \\"
  echo "   --discovery-token-ca-cert-hash sha256:<hash>"
  echo "=============================================="

else
  echo "Invalid role: use master or worker"
  exit 1
fi
