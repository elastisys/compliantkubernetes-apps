#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    helm_uninstall sc falco falco-psp-rbac
    helm_uninstall sc monitoring starboard-operator
    helm_uninstall sc monitoring starboard-operator-psp-rbac
    helm_uninstall sc monitoring vulnerability-exporter
    helm_uninstall sc monitoring ciskubebench-exporter
    helm_uninstall wc falco falco-psp-rbac
    helm_uninstall wc monitoring starboard-operator
    helm_uninstall wc monitoring starboard-operator-psp-rbac
    helm_uninstall wc monitoring vulnerability-exporter
    helm_uninstall wc monitoring ciskubebench-exporter
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
