#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

prepare_namespaces() {
  cluster_long="${1}"
  cluster_short="${2}"
  namespaces=$(helmfile -f "${ROOT}/helmfile.yaml" -e "${cluster_long}" -l app=system-namespaces template 2>/dev/null | yq4 --no-doc .metadata.name)

  for ns in ${namespaces}; do
    kubectl_do "${cluster_short}" label --overwrite=true ns "${ns}" app.kubernetes.io/managed-by=Helm
    kubectl_do "${cluster_short}" annotate --overwrite=true ns "${ns}" meta.helm.sh/release-name=system-namespaces
    kubectl_do "${cluster_short}" annotate --overwrite=true ns "${ns}" meta.helm.sh/release-namespace=kube-system
  done

  if [[ "$cluster_short" = "wc" ]]; then
    namespaces=$(helmfile -f "${ROOT}/helmfile.yaml" -e "${cluster_long}" -l app=user-namespaces template 2>/dev/null | yq4 --no-doc .metadata.name)

    for ns in ${namespaces}; do
      kubectl_do "${cluster_short}" label --overwrite=true ns "${ns}" app.kubernetes.io/managed-by=Helm
      kubectl_do "${cluster_short}" annotate --overwrite=true ns "${ns}" meta.helm.sh/release-name=user-namespaces
      kubectl_do "${cluster_short}" annotate --overwrite=true ns "${ns}" meta.helm.sh/release-namespace=kube-system
    done
  fi
}

sync_release() {
  cluster_long="${1}"

  # Needs to executed twice
  helmfile -f "${ROOT}/helmfile.yaml" -e "${cluster_long}" -l app=system-namespaces sync --args --force
  helmfile -f "${ROOT}/helmfile.yaml" -e "${cluster_long}" -l app=system-namespaces sync --args --force

  if [[ "$cluster_long" = "workload_cluster" ]]; then
    helmfile -f "${ROOT}/helmfile.yaml" -e "${cluster_long}" -l app=user-namespaces sync --args --force
    helmfile -f "${ROOT}/helmfile.yaml" -e "${cluster_long}" -l app=user-namespaces sync --args --force
  fi
}

remove_owner_label() {
  kube_ns=("kube-system" "kube-node-lease" "kube-public")

  for ns in "${kube_ns[@]}"; do
    kubectl_do "${1}" label namespace "${ns}" owner-
  done
}

apply_gatekeeper() {
  helmfile_apply "${1}" app=gatekeeper
}

run() {
  case "${1:-}" in
  execute)
      local -A clusters

      if [[ "$CK8S_CLUSTER" =~ ^(sc|both)$ ]]; then
        clusters[sc]="service_cluster"
      fi

      if [[ "$CK8S_CLUSTER" =~ ^(wc|both)$ ]]; then
        clusters[wc]="workload_cluster"
      fi

      for cluster in "${!clusters[@]}"; do
        prepare_namespaces "${clusters[${cluster}]}" "${cluster}"
        sync_release "${clusters[${cluster}]}"
        apply_gatekeeper "${cluster}"
        remove_owner_label "${cluster}"
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
