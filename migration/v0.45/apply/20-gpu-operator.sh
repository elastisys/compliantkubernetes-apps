#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    chart_version=$(yq4 '.version' "${ROOT}/helmfile.d/upstream/nvidia/gpu-operator/Chart.yaml")

    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      current_version=$(helm_do wc get metadata -n gpu-operator nvidia-gpu-operator -ojson | jq -r '.version')
      log_info "operation on workload cluster"
      if [[ "${current_version}" != "${chart_version}" ]]; then
        log_info "  - Replace nvidia-gpu-operator CRDs on wc"
        kubectl_do wc apply --server-side --force-conflicts -f "${ROOT}"/helmfile.d/upstream/nvidia/gpu-operator/crds/
      fi

      log_info "  - Upgrade nvidia-gpu-operator on wc"
      helmfile_upgrade wc app=gpu-operator
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
