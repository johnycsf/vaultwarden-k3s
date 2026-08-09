#!/usr/bin/env bash
# Install Vaultwarden on a k3s cluster with Longhorn storage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need kubectl
need openssl

if ! kubectl get storageclass longhorn >/dev/null 2>&1; then
  cat <<'EOF' >&2
Longhorn storage class not found.

Install Longhorn first (one-time, shared by these homelab apps):

  helm repo add longhorn https://charts.longhorn.io
  helm repo update
  helm install longhorn longhorn/longhorn \
    --namespace longhorn-system --create-namespace

Wait until pods are ready:

  kubectl -n longhorn-system get pod

Then re-run this script.
EOF
  exit 1
fi

DOMAIN="${DOMAIN:-}"
if [[ -z "${DOMAIN}" ]]; then
  echo "Detecting a node address for DOMAIN (override with DOMAIN=https://vault.example.com ./install.sh)..."
  NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)"
  if [[ -z "${NODE_IP}" ]]; then
    echo "Could not detect a node IP. Re-run with DOMAIN set, e.g.:" >&2
    echo "  DOMAIN=http://192.168.1.50:8081 ./install.sh" >&2
    exit 1
  fi
  DOMAIN="http://${NODE_IP}:8081"
fi

ADMIN_TOKEN="$(openssl rand -base64 48 | tr -d '\n')"

echo "Applying base manifests..."
kubectl apply -f "${ROOT}/deploy.yaml"

echo "Writing generated Secret (DOMAIN + ADMIN_TOKEN)..."
kubectl -n vaultwarden create secret generic vaultwarden \
  --from-literal=domain="${DOMAIN}" \
  --from-literal=admin-token="${ADMIN_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Restarting deployment so it picks up the Secret..."
kubectl -n vaultwarden rollout restart deployment/vaultwarden
kubectl -n vaultwarden rollout status deployment/vaultwarden --timeout=180s

TOKEN_FILE="${ROOT}/.admin-token"
umask 077
printf '%s\n' "${ADMIN_TOKEN}" > "${TOKEN_FILE}"

cat <<EOF

Vaultwarden is installed.

URL:    ${DOMAIN}
Admin:  ${DOMAIN}/admin

Your admin token was saved to:
  ${TOKEN_FILE}

Keep that file private. Open the URL, create your account, then disable public signups:

  kubectl -n vaultwarden set env deployment/vaultwarden SIGNUPS_ALLOWED=false
  kubectl -n vaultwarden rollout status deployment/vaultwarden

EOF
