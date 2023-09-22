#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

for NS in elastic-system influxdb-prometheus; do
  log_info "checking for resources in namespace $NS"
  NS_RESOURCES="$(kubectl_do sc get all -n $NS 2>&1)"
  if [[ "$NS_RESOURCES" == "No resources found in $NS namespace." ]]; then
    log_info "$NS_RESOURCES - safe to delete"
  else
    log_warn "Resources found in namespace $NS, please verify that these are okay to delete before proceeding to apply"
    echo "$NS_RESOURCES"
  fi
done
