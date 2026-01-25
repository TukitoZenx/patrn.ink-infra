#!/bin/bash
set -euo pipefail

# k3s Server Installation Script
# This script runs on first boot via cloud-init

exec > >(tee /var/log/k3s-install.log) 2>&1
echo "Starting k3s server installation at $(date)"

# Wait for cloud-init to complete
cloud-init status --wait

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    curl \
    wget \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    unzip

# Disable swap (required for Kubernetes)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load required kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Set required sysctl params
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install k3s server
%{ if install_traefik ~}
INSTALL_K3S_EXEC="server"
%{ else ~}
INSTALL_K3S_EXEC="server --disable traefik"
%{ endif ~}

curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="${k3s_version}" \
    K3S_TOKEN="${k3s_token}" \
    INSTALL_K3S_EXEC="$INSTALL_K3S_EXEC" \
    sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
until kubectl get nodes 2>/dev/null; do
    sleep 5
done

# Wait for node to be ready
kubectl wait --for=condition=Ready node --all --timeout=300s

# Create namespace for patrn-ink
kubectl create namespace patrn-ink --dry-run=client -o yaml | kubectl apply -f -

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# If Traefik is disabled, install nginx-ingress
%{ if !install_traefik ~}
echo "Installing nginx-ingress controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=LoadBalancer \
    --set controller.ingressClassResource.default=true
%{ endif ~}

# Install cert-manager for TLS certificates
echo "Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true \
    --wait

# Make kubeconfig accessible
chmod 644 /etc/rancher/k3s/k3s.yaml

echo "k3s server installation completed at $(date)"
echo "Cluster name: ${cluster_name}"
echo "k3s version: ${k3s_version}"
