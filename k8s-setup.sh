#!/bin/bash
set -e

ROLE="$1"
POD_CIDR="10.244.0.0/16"
K8S_VERSION="v1.30"
AUTHOR="Nishant Minj"

if [[ -z "$ROLE" ]]; then
  echo "Usage: $0 {master|worker|control-plane|reset}"
  exit 1
fi

echo "================================================"
echo " Kubernetes Robust Setup Script"
echo " Author : $AUTHOR"
echo " Role   : $ROLE"
echo "================================================"

############################################
# AUTO DETECT PRIVATE IP
############################################
PRIVATE_IP=$(hostname -I | awk '{print $1}')
CONTROL_PLANE_ENDPOINT="${PRIVATE_IP}:6443"

############################################
# FULL RESET
############################################
if [[ "$ROLE" == "reset" ]]; then

  echo "👉 Performing FULL Kubernetes Reset"

  sudo kubeadm reset -f || true
  sudo systemctl stop kubelet || true

  sudo rm -rf /etc/kubernetes
  sudo rm -rf /var/lib/etcd
  sudo rm -rf /var/lib/kubelet
  sudo rm -rf /etc/cni/net.d
  sudo rm -rf /var/lib/cni
  sudo rm -rf ~/.kube

  sudo iptables -F || true
  sudo iptables -t nat -F || true
  sudo iptables -t mangle -F || true

  sudo ip link delete cni0 2>/dev/null || true
  sudo ip link delete flannel.1 2>/dev/null || true

  sudo apt-get purge -y kubeadm kubelet kubectl containerd.io || true
  sudo apt-get autoremove -y || true

  echo "✅ Full reset completed"
  echo "⚠️ Reboot recommended"
  exit 0
fi

############################################
# COMMON INSTALLATION
############################################

echo "👉 Updating system"
sudo apt-get update -y
sudo apt-get install -y apt-transport-https curl ca-certificates gnupg lsb-release

echo "👉 Disabling swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "👉 Kernel configuration"
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/k8s.conf >/dev/null <<EOF
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sudo sysctl --system

echo "👉 Installing containerd"
sudo apt-get install -y containerd.io || {
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -y
  sudo apt-get install -y containerd.io
}

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "👉 Installing Kubernetes $K8S_VERSION"

curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key \
 | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

############################################
# MASTER (HA READY)
############################################
if [[ "$ROLE" == "master" ]]; then

  echo "👉 Detected Private IP: $PRIVATE_IP"
  echo "👉 Using Control Plane Endpoint: $CONTROL_PLANE_ENDPOINT"

  sudo kubeadm init \
    --pod-network-cidr=$POD_CIDR \
    --control-plane-endpoint "$CONTROL_PLANE_ENDPOINT"

  mkdir -p $HOME/.kube
  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  echo "👉 Installing Flannel CNI"
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

  echo
  echo "================================================"
  echo "👉 Worker Join Command:"
  echo "================================================"
  WORKER_JOIN=$(kubeadm token create --print-join-command)
  echo "$WORKER_JOIN"

  echo
  echo "================================================"
  echo "👉 Control Plane Join Command:"
  echo "================================================"
  CERT_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -1)
  echo "$WORKER_JOIN --control-plane --certificate-key $CERT_KEY"
  echo "================================================"

############################################
# WORKER NODE
############################################
elif [[ "$ROLE" == "worker" ]]; then

  echo "👉 Worker node prepared successfully"
  echo "👉 Run worker join command from master"

############################################
# SECONDARY CONTROL PLANE
############################################
elif [[ "$ROLE" == "control-plane" ]]; then

  echo "👉 Secondary control-plane node prepared"
  echo "👉 Run control-plane join command from master"

else
  echo "Invalid role. Use master | worker | control-plane | reset"
  exit 1
fi
