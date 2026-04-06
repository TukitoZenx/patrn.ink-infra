# patrn.ink VM Deployment

This folder now contains the only infra needed for the prototype: one VM, one Docker Compose stack, one reverse proxy, the UI, the API, and Redis on the same machine.

## What This Deploys

- `proxy`: Caddy with automatic HTTPS
- `ui`: Next.js frontend
- `api`: Go backend
- `redis`: local Redis on the VM
- `dynamodb`: external AWS DynamoDB table(s), not self-hosted

The stack is designed for a single Ubuntu VM on Google Cloud, keeps the product on `patrn.ink`, and exposes the API on `api.patrn.ink`.

## Routing

- `/`, `/dashboard`, `/auth/callback`, `/_next/*`, and UI assets on `patrn.ink` -> frontend
- `/brand/*` on `patrn.ink` -> backend
- `/:code`, `/:code/verify`, `/:code/verify-age`, `/:code/qr`, `/:code/preview` -> backend
- `api.patrn.ink/*` -> backend

This keeps short links on the main domain while moving API traffic and OAuth entrypoints to `api.patrn.ink`.

## Expected Repo Layout

By default this compose file expects:

```text
parent-folder/
  patrn.ink-api/
  patrn.ink-ui/
  patrn.ink-infra/
```

If your folders are elsewhere, set `UI_DIR` and `API_DIR` in `.env`.

## 1. Prepare DNS

Point both domains to the VM public IP.

Example:

- `patrn.ink` -> `YOUR_VM_IP`
- `api.patrn.ink` -> `YOUR_VM_IP`

If you also want `www`, point that record too, then update Caddy as needed.

## 2. OAuth Setup

Use these redirect URIs in Google and GitHub:

- `https://YOUR_API_DOMAIN/auth/google/callback`
- `https://YOUR_API_DOMAIN/auth/github/callback`

The UI callback page remains:

- `https://YOUR_DOMAIN/auth/callback`

## 3. Configure Environment

```bash
cd patrn.ink-infra
cp .env.example .env
```

Set at least:

- `DOMAIN`
- `API_DOMAIN`
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `JWT_SECRET`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`

For DynamoDB on AWS, leave `DYNAMODB_ENDPOINT` blank.

## 4. Prepare the VM

Run on a fresh Ubuntu VM:

```bash
chmod +x scripts/setup-vm.sh scripts/deploy.sh
./scripts/setup-vm.sh
```

Then log out and back in once if Docker group membership was added.

## 5. Deploy

```bash
./scripts/deploy.sh
```

## 6. Verify

Check the running services:

```bash
docker compose ps
```

Check backend health:

```bash
curl https://YOUR_API_DOMAIN/health
```

Open:

- `https://YOUR_DOMAIN`
- `https://YOUR_DOMAIN/dashboard`
- `https://YOUR_API_DOMAIN/swagger/index.html`

## Notes

- Redis is local to the VM in this setup. It is not exposed publicly.
- This is intentionally simple and prototype-friendly.
- If you later want Redis Cloud instead, remove the `redis` service and set `REDIS_ADDR`/`REDIS_PASSWORD` in the compose file.
- Caddy automatically provisions TLS once DNS is pointing to the VM.

## Updates

Redeploy after code changes:

```bash
./scripts/deploy.sh
```
