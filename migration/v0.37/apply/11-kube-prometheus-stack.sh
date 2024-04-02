#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)

    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "  - Replace kube-prometheus-stack CRDs on sc"
      kubectl_do sc apply --server-side --force-conflicts -f "${ROOT}"/helmfile.d/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds

      log_info "  - Upgrade kube-prometheus-stack on sc"
      helmfile_upgrade sc app=prometheus
    fi
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "  - Replace kube-prometheus-stack CRDs on wc"
      kubectl_do wc apply --server-side --force-conflicts -f "${ROOT}"/helmfile.d/upstream/prometheus-community/kube-prometheus-stack/charts/crds/crds

      log_info "  - Upgrade kube-prometheus-stack on wc"
      helmfile_upgrade wc app=prometheus
    fi
    ;;
  esac
}

run "${@}"
