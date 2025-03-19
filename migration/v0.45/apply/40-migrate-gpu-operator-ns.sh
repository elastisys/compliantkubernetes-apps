#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    log_info "Migrating gpu-operator namespace to be managed by Helm if it already exists"

    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      if kubectl_do wc get ns gpu-operator >/dev/null 2>&1; then
        log_info "Namespace gpu-operator exists, migrating namespace to be managed by Helm"
        kubectl_do wc label ns gpu-operator app.kubernetes.io/managed-by=Helm
        kubectl_do wc annotate ns gpu-operator meta.helm.sh/release-name=admin-namespaces
        kubectl_do wc annotate ns gpu-operator meta.helm.sh/release-namespace=kube-system
        helmfile_do wc -l app=admin-namespaces sync
      else
        log_info "Namespace gpu-operator does not exist, skipping"
      fi
    fi
    ;;
  rollback)
    log_warn "rollback not implemented"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
