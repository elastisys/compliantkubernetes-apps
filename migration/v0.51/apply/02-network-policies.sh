#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "operation on service cluster"

      if helm_installed sc kube-system common-np; then
        log_info "Deleting 'common-np' Helm release..."
        helm_uninstall sc kube-system common-np
        log_info "'common-np' Helm release deleted successfully."
      else
        log_warn "'common-np' Helm release not found. Skipping deletion."
      fi

      if helm_installed sc kube-system service-cluster-np; then
        log_info "Deleting 'service-cluster-np' Helm release..."
        helm_uninstall sc kube-system service-cluster-np
        log_info "'service-cluster-np' Helm release deleted successfully."
      else
        log_warn "'service-cluster-np' Helm release not found. Skipping deletion."
      fi

    fi
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "operation on workload cluster"

      if helm_installed wc kube-system common-np; then
        log_info "Deleting 'common-np' Helm release..."
        helm_uninstall wc kube-system common-np
        log_info "'common-np' Helm release deleted successfully."
      else
        log_warn "'common-np' Helm release not found. Skipping deletion."
      fi

      if helm_installed wc kube-system workload-cluster-np; then
        log_info "Deleting 'workload-cluster-np' Helm release..."
        helm_uninstall wc kube-system workload-cluster-np
        log_info "'workload-cluster-np' Helm release deleted successfully."
      else
        log_warn "'workload-cluster-np' Helm release not found. Skipping deletion."
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
