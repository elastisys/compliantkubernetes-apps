#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "operation on service cluster"

      helmfile_upgrade sc netpol=service
      helmfile_upgrade sc netpol=rclone
    fi

    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "no operation on workload cluster"
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
