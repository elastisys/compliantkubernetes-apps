#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  cloud_provider=$(yq_dig sc .global.ck8sCloudProvider)
  if [[ "${cloud_provider}" != "upcloud" ]]; then
    log_info "not running on upcloud, skipping"
    exit 0
  fi

  log_info "checking if using upcloud object storage v1 as it has a 1TB quota"

  s3_region_endpoint=$(yq_dig sc .objectStorage.s3.regionEndpoint)
  if [[ "${s3_region_endpoint}" =~ ((.+\.){2}upcloudobjects\.com) ]]; then
    log_info "enabling total s3 size of all buckets alert"

    yq_add sc .prometheus.s3BucketAlerts.totalSize.enabled true
    yq_add sc .prometheus.s3BucketAlerts.totalSize.sizeQuotaGB 1000
  fi
fi
