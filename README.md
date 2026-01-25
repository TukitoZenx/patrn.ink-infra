# patrn.ink Infrastructure

Kubernetes infrastructure for patrn.ink platform using **k3s** (lightweight Kubernetes).

## Structure

```
k8s/
├── base/           # Shared resources (namespace, secrets)
├── apps/
│   ├── api/        # API (patrn.ink-api)
│   └── ui/         # UI (patrn.ink)
└── kustomization.yaml

terraform/
├── main.tf         # EC2 + k3s + Cloudflare
├── scripts/        # k3s installation scripts
└── terraform.tfvars.example
```

## Quick Deploy

```bash
# 1. Deploy infrastructure (EC2 + k3s)
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init && terraform apply

# 2. Get kubeconfig from k3s server
scp ubuntu@<server-ip>:/etc/rancher/k3s/k3s.yaml ./kubeconfig.yaml
sed -i 's/127.0.0.1/<server-ip>/g' ./kubeconfig.yaml
export KUBECONFIG=./kubeconfig.yaml

# 3. Apply K8s resources
kubectl apply -k k8s/
```

## Configuration

1. Update `k8s/base/secret.yaml` with credentials
2. Update image references in deployment files
3. Configure your domain in ingress

## Images

| Service | Image                            |
| ------- | -------------------------------- |
| API     | `your-registry/patrn-api:latest` |
| UI      | `your-registry/patrn-ui:latest`  |

## Cost Comparison

| Setup             | Monthly Cost |
| ----------------- | ------------ |
| k3s (single node) | ~$22         |
| EKS (minimal)     | ~$150-200    |
