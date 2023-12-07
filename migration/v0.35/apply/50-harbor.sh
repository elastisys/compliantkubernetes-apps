#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "Upgrading harbor"
      helmfile_upgrade sc 'app=harbor'
      log_info "Deleting deprecated notary secrets"
      kubectl_do sc delete secret -n harbor harbor-notary-cert harbor-notary-ingress-cert --ignore-not-found=true
    fi
    ;;
  rollback)
    log_warn "rollback not applicable"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
