#!/usr/bin/env bash
# Safely update Vaultwarden on Kubernetes and prune unused local images when possible.
# Creates a local rollback backup first, then asks whether to keep it.
# Does NOT regenerate ADMIN_TOKEN or delete the PVC.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
NS=vaultwarden

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

ask_backup_retention() {
  local dir="$1"
  if [[ ! -d "${dir}" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    echo "No interactive terminal — keeping backup at ${dir}"
    return 0
  fi
  echo
  local reply=""
  read -r -p "Update succeeded. Keep rollback backup at ${dir}? [Y/n] " reply || true
  case "${reply:-Y}" in
    n|N|no|NO)
      rm -rf "${dir}"
      rmdir backups 2>/dev/null || true
      echo "Backup deleted."
      ;;
    *)
      echo "Backup kept."
      echo "  See ${dir}/RESTORE.txt if you need to roll back."
      ;;
  esac
}

create_backup() {
  BACKUP_DIR="${ROOT}/backups/update-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "${BACKUP_DIR}"
  echo "==> Creating rollback backup in ${BACKUP_DIR} ..."
  cp -a "${ROOT}/deploy.yaml" "${BACKUP_DIR}/" 2>/dev/null || true
  [[ -f "${ROOT}/.admin-token" ]] && cp -a "${ROOT}/.admin-token" "${BACKUP_DIR}/"
  kubectl -n "$NS" get secret vaultwarden -o yaml >"${BACKUP_DIR}/secret-vaultwarden.yaml" 2>/dev/null || true
  kubectl -n "$NS" get deploy,svc,pvc -o yaml >"${BACKUP_DIR}/resources.yaml" 2>/dev/null || true

  local pod
  pod="$(kubectl -n "$NS" get pod -l app=vaultwarden -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${pod}" ]]; then
    echo "    Archiving /data from pod ${pod} ..."
    kubectl -n "$NS" exec "${pod}" -- tar -C /data -czf - . >"${BACKUP_DIR}/data.tar.gz" \
      || echo "    Warning: could not archive pod /data"
  else
    echo "    Warning: no running Vaultwarden pod — skipped PVC data archive"
  fi

  cat >"${BACKUP_DIR}/RESTORE.txt" <<EOF
Vaultwarden k8s rollback (data + secret):

  kubectl -n vaultwarden apply -f ${BACKUP_DIR}/secret-vaultwarden.yaml
  POD=\$(kubectl -n vaultwarden get pod -l app=vaultwarden -o jsonpath='{.items[0].metadata.name}')
  kubectl -n vaultwarden exec -i "\$POD" -- tar -C /data -xzf - < ${BACKUP_DIR}/data.tar.gz
  kubectl -n vaultwarden rollout restart deployment/vaultwarden
EOF
  echo "Backup ready: ${BACKUP_DIR}"
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

create_backup

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
ask_backup_retention "${BACKUP_DIR}"
