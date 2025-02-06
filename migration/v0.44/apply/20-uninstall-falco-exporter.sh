#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    clusters=("wc" "sc")
    for cluster in "${clusters[@]}"; do
      log_info "  - Uninstalling falco-exporter in ${cluster}"
      helm_uninstall "${cluster}" falco falco-exporter
    done
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
