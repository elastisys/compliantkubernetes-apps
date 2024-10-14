#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "configuring object storage sync type on Azure"
if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  cloud_provider=$(yq_dig sc .global.ck8sCloudProvider)
  if [[ "${cloud_provider}" != "azure" ]]; then
    log_info "not running on Azure, skipping"
    exit 0
  fi

  if yq_check sc .objectStorage.sync.enabled true; then
    if yq_null sc .objectStorage.sync.destinationType; then
      log_info "objectStorage sync is enabled, will keep previous default destinationType: s3"
      yq_add sc .objectStorage.sync.destinationType "\"s3\""
    else
      log_info "sync destinationType already has an override, skipping"
    fi
  else
    log_info "object storage sync is not enabled, will use new default destinationType: azure"
  fi
fi
