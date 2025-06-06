#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    chart_version=$(yq4 '.version' "${ROOT}/helmfile.d/upstream/aquasecurity/trivy-operator/Chart.yaml")

    clusters=("${CK8S_CLUSTER}")
    if [[ "${CK8S_CLUSTER}" == "both" ]]; then
      clusters=("wc" "sc")
    fi

    for cluster in "${clusters[@]}"; do
      trivy_enabled=$(yq_dig "${cluster}" '.trivy.enabled')

      if [[ "${trivy_enabled}" == "false" ]]; then
        log_info "  - Trivy not enabled for ${cluster}, skipping"
        continue
      fi

      current_version=$(helm_do "${cluster}" get metadata -n monitoring trivy-operator -ojson | jq -r '.version')

      log_info "  - Checking if trivy-operator CRDs needs to be upgraded"
      if [[ "${current_version}" != "${chart_version}" ]]; then
        log_info "  - Replace trivy-operator CRDs on ${cluster}"
        kubectl_do "${cluster}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile.d/upstream/aquasecurity/trivy-operator/crds/
      fi

      log_info "  - Upgrade trivy-operator on ${cluster}"
      helmfile_upgrade "${cluster}" app=trivy-operator
    done

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
