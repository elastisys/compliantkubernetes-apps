#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    # --- sc ---
    if kubectl_do sc get ns fluentd > /dev/null 2>&1; then
      helm_uninstall sc fluentd fluentd
      helm_uninstall sc fluentd fluentd-configmap
      helm_uninstall sc fluentd sc-logs-retention

      kubectl_delete sc pvc fluentd fluentd-buffer-fluentd-0
      kubectl_delete sc secrets fluentd s3-credentials

      kubectl_do sc delete namespace fluentd
    fi

    helmfile_upgrade sc app=fluentd

    # --- wc ---
    helm_uninstall wc kube-system fluentd-system

    helmfile_upgrade wc app=fluentd

    kubectl_delete wc secrets fluentd opensearch
    kubectl_delete wc secrets kube-system opensearch
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
