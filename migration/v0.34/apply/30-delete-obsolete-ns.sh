#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)

    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      for NS in elastic-system influxdb-prometheus; do
        if kubectl_do sc get namespace $NS >/dev/null 2>/dev/null; then
          log_info "  - deleting unused namespace $NS in sc"
          kubectl_do sc delete namespace $NS
        else
          log_info "  - skip deleting not present namespace $NS in sc"
        fi
      done
    else
      log_info "  - skipping workload cluster"
    fi
    ;;
  rollback)
    log_warn "  - restoration of unused namespaces not implemented"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
