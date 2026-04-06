#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}"
  echo "Copy .env.example to .env and set your production values first."
  exit 1
fi

cd "${ROOT_DIR}"

docker compose --env-file "${ENV_FILE}" build
docker compose --env-file "${ENV_FILE}" up -d
docker compose --env-file "${ENV_FILE}" ps

echo
echo "Deployment complete."
echo "If DNS is already pointed to this VM, Caddy will provision HTTPS automatically."
