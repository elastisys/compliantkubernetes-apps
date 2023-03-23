#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    log_info "--- applying Gatekeeper PodSecurityPolicies for service cluster"
    helmfile_upgrade sc app=gatekeeper
    helmfile_upgrade sc app=psp

    log_info "--- applying Gatekeeper PodSecurityPolicies for workload cluster"
    helmfile_upgrade wc app=gatekeeper
    helmfile_upgrade wc app=psp
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
