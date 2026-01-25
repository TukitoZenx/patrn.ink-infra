# patrn.ink Infra – Overview

This folder contains Terraform and Kubernetes manifests for deploying the patrn.ink URL shortener platform using **k3s** (lightweight Kubernetes).

## Architecture

```
                    ┌─────────────────┐
                    │   Cloudflare    │
                    │   CDN + DNS     │
                    │   (patrn.ink)   │
                    └────────┬────────┘
                             │ HTTPS
                    ┌────────▼────────┐
                    │  EC2 + k3s      │
                    │  (Traefik)      │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───────┐ ┌────▼────┐  ┌──────▼─────┐
     │  patrn-api     │ │  patrn-ui│  │  Short URL │
     │  /api, /auth   │ │  /, /dash│  │  /:code    │
     └────────────────┘ └──────────┘  └────────────┘
                             │
                    ┌────────▼────────┐
                    │  AWS DynamoDB   │
                    │  + ElastiCache  │
                    └─────────────────┘
```

## Folder Structure

- **terraform/**: AWS EC2 + k3s cluster + Cloudflare CDN configuration
- **k8s/**: Kubernetes manifests organized for Kustomize

## Terraform (terraform/)

### What it creates:

1. **VPC** with public subnets across 2 AZs
2. **EC2 instances** running k3s (server + optional agents)
3. **Traefik Ingress Controller** (built into k3s) or nginx-ingress
4. **cert-manager** for TLS certificates
5. **Elastic IP** for stable ingress endpoint
6. **Cloudflare DNS** records pointing to the EIP
7. **Cloudflare CDN** with www → non-www redirect

### Setup:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### Required values:

- `cloudflare_zone_id`: Get from Cloudflare Dashboard → Overview
- `cloudflare_api_token`: Create at https://dash.cloudflare.com/profile/api-tokens
  (needs Zone:DNS:Edit, Zone:Zone Settings:Edit permissions)
- `ssh_public_key`: (Optional) For SSH access to instances

## Kubernetes (k8s/)

### Base resources (k8s/base/)

- `namespace.yaml`: Creates the patrn-ink namespace
- `secret.yaml`: Secrets (OAuth, JWT, Redis) - **replace placeholders!**
- `cluster-issuer.yaml`: Let's Encrypt ClusterIssuers for TLS

### Applications

#### API (k8s/apps/api/)

- Go backend handling `/api/*`, `/auth/*`, and short URL redirects (`/:code`)
- HPA: 3-10 replicas based on CPU/memory

#### UI (k8s/apps/ui/)

- Next.js frontend for dashboard and landing page
- HPA: 2-6 replicas based on CPU

### Shared infrastructure

- `ingress.yaml`: NGINX ingress routing both frontend and backend on same domain
- `pdb.yaml`: PodDisruptionBudgets for availability during node drains

## Traffic Routing

| Path                       | Service   | Description         |
| -------------------------- | --------- | ------------------- |
| `/api/*`                   | patrn-api | API endpoints       |
| `/auth/*`                  | patrn-api | OAuth callbacks     |
| `/health`, `/metrics`      | patrn-api | Health checks       |
| `/` (exact)                | patrn-ui  | Landing page        |
| `/dashboard/*`, `/login/*` | patrn-ui  | UI routes           |
| `/_next/*`, `/static/*`    | patrn-ui  | Static assets       |
| `/:code` (catch-all)       | patrn-api | Short URL redirects |

## Deployment Steps

1. **Deploy infrastructure:**

    ```bash
    cd terraform
    terraform init && terraform apply
    ```

2. **Configure kubectl:**

    ```bash
    # Option A: SSH (if ssh_public_key was provided)
    scp ubuntu@<server-ip>:/etc/rancher/k3s/k3s.yaml ./kubeconfig.yaml
    sed -i 's/127.0.0.1/<server-ip>/g' ./kubeconfig.yaml
    export KUBECONFIG=./kubeconfig.yaml

    # Option B: AWS SSM Session Manager
    aws ssm start-session --target <instance-id>
    sudo cat /etc/rancher/k3s/k3s.yaml
    ```

3. **Update secrets:**
   Edit `k8s/base/secret.yaml` with real values

4. **Deploy K8s resources:**

    ```bash
    kubectl apply -k k8s/
    ```

5. **Verify:**
    ```bash
    kubectl get pods -n patrn-ink
    kubectl get ingress -n patrn-ink
    ```

## Cost Estimates (ap-south-2)

| Component         | Monthly Cost   |
| ----------------- | -------------- |
| 1x t3.small (k3s) | ~$15           |
| Elastic IP        | ~$4            |
| 30GB gp3 EBS      | ~$3            |
| **Total**         | **~$22/month** |

### Comparison with EKS

| Setup                 | Monthly Cost |
| --------------------- | ------------ |
| **k3s (single node)** | **~$22**     |
| EKS (minimal)         | ~$150-200    |

To scale up:

- Add agent nodes (`agent_count = 1` or more)
- Use t3.medium for more resources
- Consider Reserved Instances for long-term savings
