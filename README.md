# patrn.ink Infrastructure

Kubernetes infrastructure for patrn.ink platform.

## Structure

```
k8s/
├── base/           # Shared resources (namespace, secrets)
├── apps/
│   ├── api/        # API (patrn.ink-api)
│   └── ui/         # UI (patrn.ink)
└── kustomization.yaml
```

## Quick Deploy

```bash
# Apply all resources
kubectl apply -k k8s/

# Or deploy individually
kubectl apply -k k8s/base/
kubectl apply -k k8s/apps/api/
kubectl apply -k k8s/apps/ui/
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
