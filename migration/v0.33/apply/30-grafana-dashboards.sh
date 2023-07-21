#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    log_info "- upgrade kube-prometheus-stack"
    helmfile_upgrade sc app=kube-prometheus-stack
    log_info "- remove and re-install grafana-dashbaord"
    helmfile_replace sc app=grafana-dashboards
    log_info "- restart both grafana pods"
    kubectl_do sc rollout restart deploy -n monitoring -l app.kubernetes.io/name=grafana

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
