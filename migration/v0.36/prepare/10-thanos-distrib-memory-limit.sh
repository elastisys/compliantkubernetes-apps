#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "operation on service cluster"
  if ! yq_null sc .thanos.receiveDistributor.resources.limits.memory; then
    log_info "- check if thanos distributor memory limit is less than 1Gi"
    mblimit=$(yq4 '.thanos.receiveDistributor.resources.limits.memory | select(. == "*Mi") | sub("Mi","")' "${CK8S_CONFIG_PATH}/sc-config.yaml")
    if [ -n "$mblimit" ] && ((mblimit < 1024)); then
      log_info "- increase the thanos distributor memory limit to 1Gi"
      yq4 -i '.thanos.receiveDistributor.resources.limits.memory = "1Gi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    else
      log_info "- thanos distributor memory limit is greater or equal with 1Gi, will not update it"
    fi
  fi
fi
