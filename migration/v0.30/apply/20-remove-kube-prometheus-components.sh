#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    for CLUSTER in sc wc; do
      old_state_metrics=$(kubectl_do $CLUSTER get deployments.apps -n monitoring -l app.kubernetes.io/instance=kube-prometheus-stack,app.kubernetes.io/name=kube-state-metrics,app.kubernetes.io/version!=2.8.0 --output=jsonpath={.items..metadata.name})
      old_node_exporter=$(kubectl_do $CLUSTER get daemonset -n monitoring -l app=prometheus-node-exporter --output=jsonpath={.items..metadata.name})

      if [[ -n "${old_state_metrics}" ]]; then
        log_info "- removing kube-state-metrics from $CLUSTER"
        kubectl_do $CLUSTER delete deployments.apps -l app.kubernetes.io/instance=kube-prometheus-stack,app.kubernetes.io/name=kube-state-metrics,app.kubernetes.io/version!=2.8.0 --cascade=orphan -n monitoring
      fi

      if [[ -n "${old_node_exporter}" ]]; then
        log_info "- removing prometheus-node-exporter from $CLUSTER"
        kubectl_do $CLUSTER delete daemonset -l app=prometheus-node-exporter -n monitoring
      fi
    done

    # --- sc ---
    helmfile_upgrade sc app=kube-prometheus-stack
    helmfile_upgrade sc app=thanos

    # --- wc ---
    helmfile_upgrade wc app=kube-prometheus-stack
    helmfile_upgrade wc app=user-alertmanager
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
