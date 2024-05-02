#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)

    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "Upgrading trivy-operator"
      kubectl_do wc delete crd sbomreports.aquasecurity.github.io
      kubectl_do wc delete crd clustersbomreports.aquasecurity.github.io
      helmfile_do wc -l name=trivy-operator apply
      kubectl_do wc apply -f "${ROOT}"/helmfile.d/upstream/aquasecurity/trivy-operator/crds
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
