#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

prepare_namespaces() {
  cluster_long="${1}"
  cluster_short="${2}"
  namespaces=$(helmfile -f "${ROOT}/helmfile.yaml" -e "${cluster_long}" -l app=ck8s-namespaces template 2>/dev/null | yq4 --no-doc .metadata.name)

  for ns in ${namespaces}; do
    kubectl_do "${cluster_short}" label --overwrite=true ns "${ns}" app.kubernetes.io/managed-by=Helm
    kubectl_do "${cluster_short}" annotate --overwrite=true ns "${ns}" meta.helm.sh/release-name=ck8s-namespaces
    kubectl_do "${cluster_short}" annotate --overwrite=true ns "${ns} "meta.helm.sh/release-namespace=kube-system
  done
}

sync_release() {
  # Needs to executed twice
  helmfile -f "${ROOT}/helmfile.yaml" -e "${clusters[${cluster}]}" -l app=ck8s-namespaces sync --args --force
  helmfile -f "${ROOT}/helmfile.yaml" -e "${clusters[${cluster}]}" -l app=ck8s-namespaces sync --args --force
}

run() {
  case "${1:-}" in
  execute)
      declare -A clusters

      if [[ "$CK8S_CLUSTER" =~ ^(sc|both)$ ]]; then
        clusters[sc]="service_cluster"
      fi

      if [[ "$CK8S_CLUSTER" =~ ^(wc|both)$ ]]; then
        clusters[wc]="workload_cluster"
      fi

      for cluster in "${!clusters[@]}"; do
        prepare_namespaces "${clusters[${cluster}]}" "${cluster}"
        sync_release "${clusters[${cluster}]}"
      done
    ;;
  rollback)
    log_warn "  - rollback not implemented!"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
