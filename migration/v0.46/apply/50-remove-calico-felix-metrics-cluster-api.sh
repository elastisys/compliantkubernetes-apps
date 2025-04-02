#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      if [[ "$(yq_dig sc '.global.ck8sK8sInstaller')" == "capi" ]]; then
        log_info "operation on service cluster"
        helm_uninstall sc kube-system calico-felix-metrics
      else
        log_info "only applicable on cluster-api environments, skipping"
      fi
    fi
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      if [[ "$(yq_dig wc '.global.ck8sK8sInstaller')" == "capi" ]]; then
        log_info "operation on workload cluster"
        helm_uninstall wc kube-system calico-felix-metrics
      else
        log_info "only applicable on cluster-api environments, skipping"
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
