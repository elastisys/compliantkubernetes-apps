#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if ! yq_null sc .thanos.receiveDistributor.resources.limits.memory; then
  log_info "- check if thanos distributor memory limit is less than 700Mi"
  size=$(yq4 '.thanos.receiveDistributor.resources.limits.memory | sub("Mi","")' "${CK8S_CONFIG_PATH}/sc-config.yaml")
  if ((size < 700)); then
    log_info "- increase the thanos distributor memory limit to 700Mi"
    yq4 -i '.thanos.receiveDistributor.resources.limits.memory = "700Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  else
    log_info "- thanos distributor memory limit is $size, will not update it"
  fi
fi
