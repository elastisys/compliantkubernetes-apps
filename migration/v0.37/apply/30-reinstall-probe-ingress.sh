#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      if helm_installed wc ingress-nginx ingress-nginx-probe-ingresss; then
        log_info "- Removing ingress-nginx-probe-ingresss"
        helm_uninstall wc ingress-nginx ingress-nginx-probe-ingresss
        log_info "- Install ingress-nginx-probe-ingress"
        helmfile_apply wc app=ingress-nginx-probe-ingress
      fi
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
