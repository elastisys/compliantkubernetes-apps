#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    log_info "upgrading sc starboard-operator CRDs"
    kubectl_do wc apply -f "${ROOT}/helmfile/upstream/starboard-operator/crds/"
    log_info "upgrading wc starboard-operator CRDs"
    kubectl_do sc apply -f "${ROOT}/helmfile/upstream/starboard-operator/crds/"
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
