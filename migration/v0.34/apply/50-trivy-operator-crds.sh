#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "  - applying the trivy-operator CRDs on sc"
      kubectl_do sc apply --server-side -f "${ROOT}"/helmfile/upstream/aquasecurity/trivy-operator/crds --force-conflicts
    fi
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "  - applying the trivy-operator CRDs on wc"
      kubectl_do wc apply --server-side -f "${ROOT}"/helmfile/upstream/aquasecurity/trivy-operator/crds --force-conflicts
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
