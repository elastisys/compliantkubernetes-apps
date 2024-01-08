#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      if [[ "$(yq_dig sc .trivy.enabled)" == "true" && "$(helm_chart_version sc monitoring trivy-operator)" != "0.19.1" ]]; then
        log_info "  - applying the trivy-operator CRDs on sc"
        kubectl_do sc apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/aquasecurity/trivy-operator/crds
        log_info "  - upgrade trivy-operator on sc"
        kubectl_do sc app=trivy-operator
      fi
    fi
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      if [[ "$(yq_dig wc .trivy.enabled)" == "true" && "$(helm_chart_version wc monitoring trivy-operator)" != "0.19.1" ]]; then
        log_info "  - applying the trivy-operator CRDs on wc"
        kubectl_do wc apply --server-side --force-conflicts -f "${ROOT}"/helmfile/upstream/aquasecurity/trivy-operator/crds
        log_info "  - upgrade trivy-operator on wc"
        kubectl_do wc app=trivy-operator
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
