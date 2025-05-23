#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)

    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "upgrading gatekeeper in service cluster"
      helmfile_do sc -l name=gatekeeper-templates apply
      helmfile_upgrade sc app=gatekeeper
    fi
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "upgrading gatekeeper in workload cluster"
      helmfile_do wc -l name=gatekeeper-templates apply
      helmfile_upgrade wc app=gatekeeper
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
