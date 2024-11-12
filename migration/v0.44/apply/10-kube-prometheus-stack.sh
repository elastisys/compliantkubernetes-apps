#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    chart_version=$(yq4 '.version' "${ROOT}/helmfile.d/upstream/prometheus-community/kube-prometheus-stack/Chart.yaml")
    clusters=("${CK8S_CLUSTER}")
    if [[ "${CK8S_CLUSTER}" == "both" ]]; then
      clusters=("wc" "sc")
    fi

    for cluster in "${clusters[@]}"; do
      current_version=$(helm_do "${cluster}" get metadata -n monitoring kube-prometheus-stack -ojson | jq -r '.version')

      log_info "  - Checking if kube-promethes-stack CRDs needs to be upgraded"
      if [[ "${current_version}" != "${chart_version}" ]]; then
        log_info "  - Replace kube-prometheus-stack CRDs on ${cluster}"
        kubectl_do "${cluster}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile.d/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds
      fi

      log_info "  - Upgrade kube-prometheus-stack on ${cluster}"
      helmfile_upgrade "${cluster}" app=prometheus
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
