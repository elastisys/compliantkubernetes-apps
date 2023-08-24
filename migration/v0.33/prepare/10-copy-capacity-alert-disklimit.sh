#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "- checking if .prometheus.capacityManagementAlerts.disklimit needs to be copied"

yq_copy common .prometheus.capacityManagementAlerts.disklimit .prometheus.capacityManagementAlerts.persistentVolume.limit
yq_copy sc .prometheus.capacityManagementAlerts.disklimit .prometheus.capacityManagementAlerts.persistentVolume.limit
yq_copy wc .prometheus.capacityManagementAlerts.disklimit .prometheus.capacityManagementAlerts.persistentVolume.limit
