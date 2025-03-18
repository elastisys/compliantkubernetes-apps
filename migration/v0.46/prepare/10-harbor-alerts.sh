#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "operation on service cluster"
  if [[ $(yq_dig sc .harbor.alerts.maxTotalStorageUsedGB) -lt 1500 ]]; then
    yq_remove sc .harbor.alerts.maxTotalStorageUsedGB
  fi
  if [[ $(yq_dig sc .harbor.alerts.maxTotalArtifacts) -lt 3000 ]]; then
    yq_remove sc .harbor.alerts.maxTotalArtifacts
  fi
  if yq_check sc .harbor.alerts "{}"; then
    yq_remove sc .harbor.alerts
  fi
fi
