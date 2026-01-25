#!/bin/bash
set -euo pipefail

# k3s Agent Installation Script
# This script runs on first boot via cloud-init

exec > >(tee /var/log/k3s-install.log) 2>&1
echo "Starting k3s agent installation at $(date)"

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
    ca-certificates

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

# Wait for server to be ready (simple retry loop)
echo "Waiting for k3s server to be available..."
MAX_RETRIES=30
RETRY_COUNT=0
until curl -sk https://${server_ip}:6443/ping 2>/dev/null || [ $RETRY_COUNT -eq $MAX_RETRIES ]; do
    echo "Waiting for k3s server... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT+1))
done

# Install k3s agent
curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="${k3s_version}" \
    K3S_URL="https://${server_ip}:6443" \
    K3S_TOKEN="${k3s_token}" \
    sh -

echo "k3s agent installation completed at $(date)"
