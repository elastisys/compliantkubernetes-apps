#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    # Note: 00-template.sh will be skipped by the upgrade command
    log_info "Upgrading prometheus-opensearch-exporter"

    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "operation on service cluster"
      kubectl_delete sc deployment opensearch-system prometheus-opensearch-exporter
      log_info "- Removing opensearch-configurer"
      helmfile_destroy sc name=opensearch-configurer
      log_info "- Upgrading Opensearch"
      helmfile_do sc -lapp=opensearch -lnetpol=service sync
    fi
    ;;
  rollback)
    log_warn "rollback not implemented"

    # if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
    #   log_info "rollback operation on service cluster"
    # fi
    # if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
    #   log_info "rollback operation on workload cluster"
    # fi
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
