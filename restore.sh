#!/usr/bin/env bash
# Restore Vaultwarden k8s data (+ optional secret) from a backups/update-* snapshot.
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
need kubectl

if [[ ! -d backups ]]; then
  echo "No backups/ directory found. Run ./update.sh at least once first." >&2
  exit 1
fi

mapfile -t DIRS < <(ls -1dt backups/update-* 2>/dev/null || true)
if ((${#DIRS[@]} == 0)); then
  echo "No backups/update-* snapshots found." >&2
  exit 1
fi

echo "Available backups (newest first):"
i=1
for d in "${DIRS[@]}"; do
  size="$(du -sh "$d" 2>/dev/null | awk '{print $1}')"
  echo "  ${i}) ${d}  (${size})"
  i=$((i + 1))
done

choice=""
if [[ -t 0 ]]; then
  read -r -p "Restore which backup number? [1] " choice || true
else
  echo "Non-interactive: use ./restore.sh with a TTY to choose a backup." >&2
  exit 1
fi
choice="${choice:-1}"
if ! [[ "${choice}" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#DIRS[@]} )); then
  echo "Invalid selection." >&2
  exit 1
fi
SRC="${DIRS[$((choice - 1))]}"

if [[ ! -f "${SRC}/data.tar.gz" ]]; then
  echo "Backup ${SRC} is missing data.tar.gz" >&2
  exit 1
fi

echo
echo "This will REPLACE /data in the Vaultwarden pod from ${SRC}."
read -r -p "Type 'restore' to continue: " confirm || true
if [[ "${confirm}" != "restore" ]]; then
  echo "Aborted."
  exit 1
fi

if [[ -f "${SRC}/secret-vaultwarden.yaml" ]]; then
  echo "==> Restoring Secret..."
  kubectl -n "$NS" apply -f "${SRC}/secret-vaultwarden.yaml"
fi
[[ -f "${SRC}/.admin-token" ]] && cp -a "${SRC}/.admin-token" .admin-token

pod="$(kubectl -n "$NS" get pod -l app=vaultwarden -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -z "${pod}" ]]; then
  echo "No running Vaultwarden pod. Apply deploy.yaml / wait for Ready, then retry." >&2
  exit 1
fi

echo "==> Restoring /data into ${pod} ..."
kubectl -n "$NS" exec "${pod}" -- sh -c 'rm -rf /data/* /data/.[!.]* /data/..?* 2>/dev/null || true'
kubectl -n "$NS" exec -i "${pod}" -- tar -C /data -xzf - <"${SRC}/data.tar.gz"
echo "==> Restarting deployment..."
kubectl -n "$NS" rollout restart deployment/vaultwarden
kubectl -n "$NS" rollout status deployment/vaultwarden --timeout=180s
echo
echo "Restore finished from ${SRC}."
