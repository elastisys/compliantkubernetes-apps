#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "Running alertmanager config migration in WC..."
      config_load wc
      yq_move wc '.user.alertmanager.ingress.enabled' '.prometheus.devAlertmanager.ingressEnabled'
      yq_move wc '.user.alertmanager.resources' '.prometheus.alertmanagerSpec.resources'
      yq_move wc '.user.alertmanager.tolerations' '.prometheus.alertmanagerSpec.tolerations'
      yq_move wc '.user.alertmanager.affinity' '.prometheus.alertmanagerSpec.affinity'
      yq_move wc '.user.alertmanager.topologySpreadConstraints' '.prometheus.alertmanagerSpec.topologySpreadConstraints'
      yq_remove wc '.user.alertmanager'
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
