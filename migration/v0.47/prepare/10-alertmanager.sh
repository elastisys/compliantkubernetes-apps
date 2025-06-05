#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
    log_info "Running alertmanager config migration in WC..."
    yq_move wc '.user.alertmanager.ingress.enabled' '.prometheus.devAlertmanager.ingressEnabled'
    yq_move wc '.user.alertmanager.resources' '.prometheus.alertmanagerSpec.resources'
    yq_move wc '.user.alertmanager.tolerations' '.prometheus.alertmanagerSpec.tolerations'
    yq_move wc '.user.alertmanager.affinity' '.prometheus.alertmanagerSpec.affinity'
    yq_move wc '.user.alertmanager.topologySpreadConstraints' '.prometheus.alertmanagerSpec.topologySpreadConstraints'
    yq_remove wc '.user.alertmanager'
    yq_remove common '.user.alertmanager'
fi
