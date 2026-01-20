# patrn.ink Infra – Overview

This folder contains Kubernetes manifests for deploying the patrn.ink platform. It is organized for Kustomize and targets a single namespace: patrn-ink.

## Top-level layout

- k8s/ is the root of all manifests.
- k8s/kustomization.yaml applies everything (base + apps + shared infra).

## Base resources (k8s/base/)

- namespace.yaml: Creates the patrn-ink namespace.
- secret.yaml: Holds app secrets (OAuth, JWT, Redis). Replace placeholders before applying.
- kustomization.yaml: Bundles base resources.

## Applications

### API (k8s/apps/api/)

- deployment.yaml: Deploys patrn-api with probes, resource limits, and anti-affinity.
- service.yaml: ClusterIP service for the API.
- configmap.yaml: Runtime config (env vars) for the API.
- hpa.yaml: Autoscaling based on CPU and memory.
- kustomization.yaml: Bundles API resources and common labels.

### UI (k8s/apps/ui/)

- deployment.yaml: Deploys patrn-ui with probes, resource limits, and anti-affinity.
- service.yaml: ClusterIP service for the UI.
- configmap.yaml: Runtime config (env vars) for the UI.
- hpa.yaml: Autoscaling based on CPU.
- kustomization.yaml: Bundles UI resources and common labels.

## Shared infrastructure

- ingress.yaml: Ingress definition for the public domain.
    - Configured for NGINX Ingress Controller.
    - Uses cert-manager (cluster issuer) for TLS.
    - Routes API paths to patrn-api and UI paths to patrn-ui.
- pdb.yaml: PodDisruptionBudgets to maintain availability during node drains.

## How traffic flows

- The ingress routes /api, /auth, /health, /metrics to the API service.
- UI assets and routes (/, /\_next, /static, etc.) go to the UI service.
- Short URLs are routed to the API.

## What you must customize

- k8s/base/secret.yaml: Real secrets and credentials.
- k8s/apps/\*/deployment.yaml: Image names for ECR (or your registry).
- k8s/ingress.yaml: Domain and cert-manager issuer as needed.

## Apply

Use Kustomize with kubectl:

- kubectl apply -k k8s/

Or apply per layer:

- kubectl apply -k k8s/base/
- kubectl apply -k k8s/apps/api/
- kubectl apply -k k8s/apps/ui/
