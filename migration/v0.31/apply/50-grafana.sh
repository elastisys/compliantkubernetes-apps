#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    log_info "uninstalling old ops-grafana"
    helmfile_apply sc app=kube-prometheus-stack

    log_info "uninstalling old grafana-dashboards"
    if helm_installed sc monitoring grafana-ops; then
      helm_uninstall sc monitoring grafana-ops
    else
      log_info "release is not installed, skipping.."
    fi

    log_info "installing new grafana-dashboards"
    helmfile_apply sc app=grafana-dashboards

    log_info "installing new ops-grafana"
    helmfile_apply sc app=ops-grafana

    log_info "upgrading user-grafana"
    helmfile_apply sc app=user-grafana
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
