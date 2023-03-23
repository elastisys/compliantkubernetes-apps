#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    helmfile_upgrade sc "app=service-cluster-np"
    helmfile_upgrade sc "app=common-np"

    helmfile_upgrade wc "app=workload-cluster-np"
    helmfile_upgrade wc "app=common-np"
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
