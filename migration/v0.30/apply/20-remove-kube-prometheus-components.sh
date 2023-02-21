#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    for CLUSTER in sc wc; do
      log_info "  - removing kube-state-metrics from $CLUSTER"
      kubectl_do $CLUSTER delete deployments.apps -l app.kubernetes.io/instance=kube-prometheus-stack,app.kubernetes.io/name=kube-state-metrics --cascade=orphan -n monitoring
      log_info "  - removing prometheus-node-exporter from $CLUSTER"
      kubectl_do $CLUSTER delete daemonset -l app=prometheus-node-exporter -n monitoring
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
