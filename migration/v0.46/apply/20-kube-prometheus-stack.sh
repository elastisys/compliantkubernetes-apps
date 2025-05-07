#!/usr/bin/env bash

set -euo pipefail
trap 'log_fatal "Error occurred on line $LINENO"' ERR

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

source "${ROOT}/scripts/migration/lib.sh"

# Check if CK8S_CLUSTER is set
if [[ -z "${CK8S_CLUSTER:-}" ]]; then
  log_fatal "CK8S_CLUSTER is not set. Please export CK8S_CLUSTER=wc|sc|both before running."
fi

# Check if helmfile exists
if ! command -v helmfile >/dev/null 2>&1; then
  log_fatal "helmfile is not installed. Please install it before running."
fi

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

      log_info "Upgrading kube-prometheus-stack on ${cluster}: ${current_version} -> ${chart_version}"

      log_info "  - Checking if kube-prometheus-stack CRDs need to be upgraded on ${cluster}"
      if [[ "${current_version}" != "${chart_version}" ]]; then
        log_info "  - Replace kube-prometheus-stack CRDs on ${cluster}"
        kubectl_do "${cluster}" apply --server-side --force-conflicts -f "${ROOT}/helmfile.d/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds"
      else
        log_info "  - CRDs up-to-date on ${cluster}, skipping"
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
