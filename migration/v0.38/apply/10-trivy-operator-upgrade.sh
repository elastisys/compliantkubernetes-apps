#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      if [[ "$(yq_dig sc .trivy.enabled)" == "true" && "$(helm_chart_version sc monitoring trivy-operator)" != "0.22.1" ]]; then
        log_info "Upgrading trivy-operator in sc"
        kubectl_do sc delete crd sbomreports.aquasecurity.github.io
        kubectl_do sc delete crd clustersbomreports.aquasecurity.github.io
        kubectl_do sc apply -f "${ROOT}"/helmfile.d/upstream/aquasecurity/trivy-operator/crds
        helmfile_do sc -l name=trivy-operator apply
      fi
    fi
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      if [[ "$(yq_dig wc .trivy.enabled)" == "true" && "$(helm_chart_version wc monitoring trivy-operator)" != "0.22.1" ]]; then
        log_info "Upgrading trivy-operator in wc"
        kubectl_do wc delete crd sbomreports.aquasecurity.github.io
        kubectl_do wc delete crd clustersbomreports.aquasecurity.github.io
        kubectl_do wc apply -f "${ROOT}"/helmfile.d/upstream/aquasecurity/trivy-operator/crds
        helmfile_do wc -l name=trivy-operator apply
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
