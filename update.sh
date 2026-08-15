#!/usr/bin/env bash
# Safely update Vaultwarden on Kubernetes and prune unused local images when possible.
# Safe to run while the app is live. Does NOT regenerate ADMIN_TOKEN or delete the PVC.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need kubectl

if ! kubectl get storageclass longhorn >/dev/null 2>&1; then
  echo "Longhorn StorageClass not found — fix storage before updating." >&2
  exit 1
fi

if ! kubectl -n vaultwarden get deploy vaultwarden >/dev/null 2>&1; then
  echo "Vaultwarden is not installed yet. Run ./install.sh first." >&2
  exit 1
fi

echo "==> Applying manifests (keeps existing Secret / PVC)..."
kubectl apply -f "${ROOT}/deploy.yaml"
echo "==> Rolling out new pods (picks up newer :latest digests)..."
kubectl -n vaultwarden rollout restart deployment/vaultwarden
kubectl -n vaultwarden rollout status deployment/vaultwarden --timeout=180s

echo "==> Pruning unused images on this machine (dangling/unused only)..."
if command -v k3s >/dev/null 2>&1; then
  sudo k3s crictl rmi --prune 2>/dev/null || echo "(skipped k3s prune — need sudo or crictl)"
elif command -v docker >/dev/null 2>&1; then
  docker image prune -f
fi

echo
echo "Update finished. Vault data PVC and admin Secret were left untouched."
echo "  kubectl -n vaultwarden get svc vaultwarden"
