# patrn.ink Infrastructure Guide

## 📖 Complete Beginner's Guide

This document explains the entire infrastructure of **patrn.ink** (a URL shortener platform) in simple terms. Even if you have no technical background, you'll understand what each piece does by the end of this guide.

---

## 🏗️ What is Infrastructure?

Think of infrastructure like the foundation, plumbing, and electrical wiring of a house. Before you can live in a house (use an app), someone needs to:

- Build the foundation (servers)
- Connect electricity (network)
- Set up plumbing (data storage)
- Install locks (security)

This folder contains all the "blueprints" to build and run the patrn.ink platform.

---

## 🎯 The Big Picture

```
                    ┌─────────────────────────┐
                    │     YOU (the user)      │
                    │   typing patrn.ink      │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │      CLOUDFLARE         │
                    │  (Security & Speed)     │
                    │  • Protects from attacks│
                    │  • Makes it faster      │
                    │  • Manages domain name  │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │     AWS EC2 SERVER      │
                    │   (The actual computer) │
                    │                         │
                    │  ┌───────────────────┐  │
                    │  │       k3s         │  │
                    │  │   (Kubernetes)    │  │
                    │  │  ┌─────┐ ┌─────┐  │  │
                    │  │  │ API │ │ UI  │  │  │
                    │  │  └─────┘ └─────┘  │  │
                    │  └───────────────────┘  │
                    └───────────┬─────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │    AWS DynamoDB         │
                    │   (The database)        │
                    │  Stores all your links  │
                    └─────────────────────────┘
```

---

## 📁 Folder Structure Explained

```
patrn.ink-infra/
├── terraform/     ← Creates the cloud servers (AWS + Cloudflare)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── scripts/   ← Installation scripts that run on servers
│
└── k8s/           ← Tells Kubernetes HOW to run the apps
    ├── base/      ← Basic setup (namespace, secrets)
    ├── apps/
    │   ├── api/   ← Backend app configuration
    │   └── ui/    ← Frontend app configuration
    ├── ingress.yaml
    └── pdb.yaml
```

---

## 🌍 Part 1: Terraform (Creating the Servers)

### What is Terraform?

Terraform is like a **magic spell book**. Instead of manually clicking buttons in AWS to create servers, you write instructions in code, and Terraform creates everything automatically.

**Benefit**: You can delete everything and recreate it identically with one command!

---

### 📄 main.tf - The Main Blueprint

This file creates all the cloud resources:

#### 1️⃣ VPC (Virtual Private Cloud)

```
Think of it as: A private neighborhood for your servers
```

| What it does              | Real-world analogy           |
| ------------------------- | ---------------------------- |
| Creates a private network | Building a gated community   |
| Assigns IP addresses      | Giving each house an address |
| Controls who can enter    | Security guards at the gate  |

**Settings**:

- IP range: `10.0.0.0/16` (65,000+ possible addresses)
- 2 availability zones (like having buildings in 2 cities for backup)

---

#### 2️⃣ Security Group (Firewall)

```
Think of it as: A bouncer at a nightclub
```

| Rule           | Port | Who can access? | Purpose                      |
| -------------- | ---- | --------------- | ---------------------------- |
| SSH            | 22   | Admins only     | Remote login to fix problems |
| Kubernetes API | 6443 | Admins only     | Control the cluster          |
| HTTP           | 80   | Everyone        | Regular web traffic          |
| HTTPS          | 443  | Everyone        | Secure web traffic           |

---

#### 3️⃣ EC2 Instance (The Server)

```
Think of it as: Renting a computer in Amazon's data center
```

| Setting       | Value        | Meaning                                  |
| ------------- | ------------ | ---------------------------------------- |
| Instance type | `t3.small`   | 2 CPU cores, 2GB RAM                     |
| Storage       | 30 GB        | Hard drive size                          |
| OS            | Ubuntu 22.04 | Operating system (like Windows but free) |
| Location      | ap-south-2   | Hyderabad, India data center                |

**Monthly cost**: ~$15-25 (compared to $150+ for managed Kubernetes)

---

#### 4️⃣ Elastic IP

```
Think of it as: A permanent phone number
```

When you restart a server, its IP address normally changes. An Elastic IP is a **fixed address** that stays the same forever, so `patrn.ink` always points to the right place.

---

#### 5️⃣ Cloudflare (CDN + DNS)

```
Think of it as: A super-fast delivery network + phone book
```

**DNS (Domain Name System)**:

- Translates `patrn.ink` → `123.45.67.89` (the server's IP)
- Like a phone book translating "John Smith" → "555-1234"

**CDN (Content Delivery Network)**:

- Caches your website on servers worldwide
- Users get content from the nearest server (faster!)
- Protects against attacks (DDoS protection)

**Settings configured**:
| Setting | Value | Meaning |
|---------|-------|---------|
| SSL Mode | Full | Encrypted everywhere |
| HTTPS Redirect | On | Always use secure connection |
| www redirect | 301 | `www.patrn.ink` → `patrn.ink` |
| Min TLS | 1.2 | Modern encryption only |

---

### 📄 variables.tf - Customizable Settings

These are like the "options" when ordering a pizza:

| Variable               | Default      | What it controls                       |
| ---------------------- | ------------ | -------------------------------------- |
| `aws_region`           | `ap-south-2` | Which AWS data center                  |
| `cluster_name`         | `patrn-ink`  | Name for all resources                 |
| `server_instance_type` | `t3.small`   | Server power level                     |
| `agent_count`          | `0`          | Extra worker servers (none by default) |
| `domain_name`          | `patrn.ink`  | Your website address                   |

---

### 📄 scripts/k3s-server.sh - Server Setup Script

This script runs automatically when the server first boots. It:

1. **Updates the system** - Installs security patches
2. **Installs k3s** - Lightweight Kubernetes
3. **Configures networking** - Enables container networking
4. **Installs cert-manager** - Automatically gets SSL certificates
5. **Installs Helm** - Package manager for Kubernetes

---

## ☸️ Part 2: Kubernetes (k8s) - Running the Apps

### What is Kubernetes?

Imagine you're running a restaurant:

- **Without Kubernetes**: You personally manage every waiter, cook, and dishwasher
- **With Kubernetes**: You hire a manager who handles everything automatically

Kubernetes is the **manager** that:

- Starts your apps
- Restarts them if they crash
- Scales up when busy (more waiters during rush hour)
- Scales down when quiet (fewer staff at 3 AM)

### What is k3s?

k3s is a **lightweight version** of Kubernetes. It's like a compact car vs. a semi-truck:

- Full Kubernetes (EKS): Powerful but expensive ($150+/month)
- k3s: Perfect for small-medium projects ($15-25/month)

---

### 📄 k8s/base/namespace.yaml

```
Think of it as: Creating a folder to organize your apps
```

```yaml
name: patrn-ink
```

All resources for patrn.ink live in this namespace, separate from other apps.

---

### 📄 k8s/base/secret.yaml

```
Think of it as: A locked safe for passwords
```

Stores sensitive information:
| Secret | Purpose |
|--------|---------|
| `GOOGLE_CLIENT_ID` | For "Login with Google" |
| `GOOGLE_CLIENT_SECRET` | Google OAuth password |
| `JWT_SECRET` | Encrypts user sessions |
| `REDIS_ADDR` | Cache server address |

⚠️ **Important**: Never commit real secrets to Git! Use placeholder values.

---

### 📄 k8s/base/cluster-issuer.yaml

```
Think of it as: Automatic SSL certificate ordering
```

**What are SSL certificates?**

- They enable the 🔒 padlock in your browser
- They encrypt data between users and your server
- Without them, browsers show "Not Secure" warnings

**Let's Encrypt** provides free certificates. cert-manager automatically:

1. Requests certificates
2. Proves you own the domain
3. Renews them every 90 days

---

### 📄 k8s/apps/api/deployment.yaml

```
Think of it as: Instructions for running the backend app
```

The API handles:

- Creating short links (`patrn.ink/abc123`)
- User authentication
- Analytics tracking

**Key settings explained**:

| Setting                                 | Value                    | Meaning                |
| --------------------------------------- | ------------------------ | ---------------------- |
| `replicas: 1`                           | Start with 1 copy        | Can scale up to 4      |
| `image: your-registry/patrn-api:latest` | Docker image to run      | Your app code          |
| `containerPort: 8080`                   | App listens on port 8080 | Internal communication |
| `cpu: 100m - 500m`                      | 10-50% of one CPU core   | Resource limits        |
| `memory: 128Mi - 512Mi`                 | 128-512 MB RAM           | Resource limits        |

**Health checks**:

```
livenessProbe:  "Are you alive?" → If no, restart the app
readinessProbe: "Are you ready?" → If no, don't send traffic
```

---

### 📄 k8s/apps/api/service.yaml

```
Think of it as: A phone number for the app
```

```yaml
port: 80 → targetPort: 8080
```

Other apps call port 80, Kubernetes routes to port 8080 on the container.

---

### 📄 k8s/apps/api/hpa.yaml

```
Think of it as: Auto-hiring staff during rush hour
```

**HPA = Horizontal Pod Autoscaler**

| Condition    | Action              |
| ------------ | ------------------- |
| CPU > 70%    | Add more app copies |
| CPU < 70%    | Remove extra copies |
| Memory > 80% | Add more app copies |

**Limits**: 1 minimum, 4 maximum copies

---

### 📄 k8s/apps/ui/deployment.yaml

```
Think of it as: Instructions for running the frontend app
```

The UI handles:

- Landing page
- Dashboard
- Login pages

**Key differences from API**:
| Setting | UI | API |
|---------|-----|-----|
| Port | 3000 (Next.js) | 8080 (Go) |
| Memory | 64-256 MB | 128-512 MB |
| CPU | 50-200m | 100-500m |

---

### 📄 k8s/ingress.yaml

```
Think of it as: A traffic cop directing visitors
```

**How routing works**:

```
User visits patrn.ink/...
        │
        ▼
┌───────────────────────────────────────┐
│           Ingress Controller          │
│  (Traefik - built into k3s)           │
└───────────────────┬───────────────────┘
                    │
    ┌───────────────┼───────────────┐
    ▼               ▼               ▼
  /api/*         /dashboard      /abc123
  /auth/*        /login          (short URL)
  /health        /settings
    │               │               │
    ▼               ▼               ▼
 ┌─────┐        ┌─────┐         ┌─────┐
 │ API │        │ UI  │         │ API │
 └─────┘        └─────┘         └─────┘
```

**Route table**:
| Path | Goes to | Purpose |
|------|---------|---------|
| `/api/*` | API | Backend endpoints |
| `/auth/*` | API | Login callbacks |
| `/health` | API | Health checks |
| `/dashboard/*` | UI | User dashboard |
| `/login/*` | UI | Login page |
| `/` (exact) | UI | Landing page |
| `/*` (anything else) | API | Short URL redirect |

---

### 📄 k8s/pdb.yaml

```
Think of it as: Minimum staffing requirements
```

**PDB = Pod Disruption Budget**

During maintenance (like server updates):

- At least 1 API copy must stay running
- At least 1 UI copy must stay running

This prevents downtime during planned updates.

---

## 🚀 How Deployment Works

### Step 1: Create Infrastructure (One-time)

```bash
cd terraform
terraform init      # Download required plugins
terraform plan      # Preview what will be created
terraform apply     # Create everything!
```

This creates:

- ✅ VPC (network)
- ✅ EC2 instance (server)
- ✅ k3s cluster (Kubernetes)
- ✅ Elastic IP
- ✅ Cloudflare DNS records

### Step 2: Get Cluster Access

First, get your server's IP address (the Elastic IP created by Terraform):

```bash
# Get the server IP from Terraform output
terraform output server_public_ip
# Example output: 52.66.123.45
```

Then use that IP to retrieve the Kubernetes config:

```bash
# Replace <server-ip> with your actual IP (e.g., 52.66.123.45)

# Copy the Kubernetes config file from the server
scp ubuntu@<server-ip>:/etc/rancher/k3s/k3s.yaml ./kubeconfig.yaml

# The config file references 127.0.0.1 (localhost) by default.
# Update it to use your server's real IP so you can connect remotely:
sed -i 's/127.0.0.1/<server-ip>/g' ./kubeconfig.yaml

# Tell kubectl to use this config file
export KUBECONFIG=./kubeconfig.yaml

# Verify connection works
kubectl get nodes
```

> 💡 **Tip**: The Elastic IP is a permanent address that stays the same even if you restart the server. It's the same IP that `patrn.ink` points to via Cloudflare DNS.

### Step 3: Deploy Applications

```bash
kubectl apply -k k8s/
```

This creates:

- ✅ Namespace
- ✅ Secrets
- ✅ API deployment + service
- ✅ UI deployment + service
- ✅ Ingress rules
- ✅ Autoscaling rules

---

## 🔄 Traffic Flow (Complete Journey)

```
1. User types: patrn.ink/abc123

2. DNS Resolution (Cloudflare):
   patrn.ink → 52.66.xxx.xxx (Elastic IP)

3. Cloudflare CDN:
   - Checks for cached response
   - Adds security headers
   - Forwards to origin

4. Traefik Ingress:
   - Receives HTTPS request
   - Matches /abc123 → API service

5. Kubernetes Service:
   - Load balances across API pods
   - Routes to healthy container

6. API Container:
   - Looks up abc123 in DynamoDB
   - Returns 301 redirect to original URL

7. Response flows back:
   API → Service → Ingress → Cloudflare → User
```

---

## 💰 Cost Breakdown

| Resource      | Monthly Cost | Notes               |
| ------------- | ------------ | ------------------- |
| EC2 t3.small  | ~$15         | 24/7 running        |
| Elastic IP    | Free         | (when attached)     |
| Data transfer | ~$1-5        | Depends on traffic  |
| Cloudflare    | Free         | Free tier is plenty |
| DynamoDB      | ~$1-10       | Pay per request     |
| **Total**     | **~$20-30**  | vs $150+ for EKS    |

---

## 🔒 Security Features

### At the Network Level

- ✅ Security groups block unauthorized access
- ✅ Only ports 80, 443, 22, 6443 are open
- ✅ VPC isolates resources

### At the CDN Level (Cloudflare)

- ✅ DDoS protection
- ✅ WAF (Web Application Firewall)
- ✅ Bot protection
- ✅ Always HTTPS

### At the Kubernetes Level

- ✅ Containers run as non-root user
- ✅ Read-only file systems (where possible)
- ✅ Resource limits prevent runaway processes
- ✅ Secrets stored securely

### At the Application Level

- ✅ JWT authentication
- ✅ OAuth (Google login)
- ✅ CORS restrictions

---

## 📊 Monitoring & Health

### Automatic Health Checks

Every 10-20 seconds, Kubernetes:

1. Calls `/health` endpoint
2. If it fails 3 times → restarts the container

### Automatic Scaling

When traffic increases:

1. HPA sees CPU > 70%
2. Creates new pod replicas
3. Traffic spreads across all copies

---

## 🛠️ Common Operations

### View Running Pods

```bash
kubectl get pods -n patrn-ink
```

### View Logs

```bash
kubectl logs -n patrn-ink deployment/patrn-api
```

### Scale Manually

```bash
kubectl scale deployment/patrn-api --replicas=3 -n patrn-ink
```

### Restart an App

```bash
kubectl rollout restart deployment/patrn-api -n patrn-ink
```

---

## 🎓 Glossary

| Term                 | Definition                                     |
| -------------------- | ---------------------------------------------- |
| **AWS**              | Amazon Web Services - cloud computing platform |
| **EC2**              | Elastic Compute Cloud - virtual servers        |
| **VPC**              | Virtual Private Cloud - isolated network       |
| **Terraform**        | Infrastructure as Code tool                    |
| **Kubernetes (k8s)** | Container orchestration platform               |
| **k3s**              | Lightweight Kubernetes distribution            |
| **Pod**              | Smallest Kubernetes unit (runs containers)     |
| **Deployment**       | Manages pod replicas                           |
| **Service**          | Stable network endpoint for pods               |
| **Ingress**          | Routes external traffic to services            |
| **HPA**              | Auto-scales pods based on metrics              |
| **ConfigMap**        | Stores configuration (non-secret)              |
| **Secret**           | Stores sensitive data (encrypted)              |
| **Namespace**        | Virtual cluster within a cluster               |
| **CDN**              | Content Delivery Network                       |
| **DNS**              | Domain Name System                             |
| **SSL/TLS**          | Encryption protocols (the 🔒 in browsers)      |
| **Let's Encrypt**    | Free SSL certificate authority                 |

---

## 📚 Further Learning

1. **Terraform**: [terraform.io/docs](https://terraform.io/docs)
2. **Kubernetes**: [kubernetes.io/docs](https://kubernetes.io/docs)
3. **k3s**: [k3s.io](https://k3s.io)
4. **Cloudflare**: [developers.cloudflare.com](https://developers.cloudflare.com)

---

_Last updated: January 2026_
