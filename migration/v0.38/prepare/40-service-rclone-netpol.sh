#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "operation on service cluster"

  if ! yq_null sc .networkPolicies.rcloneSync; then
    yq_move sc .networkPolicies.rcloneSync .networkPolicies.rclone
  fi
  if ! yq_null sc .networkPolicies.rclone.destinationObjectStorageS3; then
    yq_move sc .networkPolicies.rclone.destinationObjectStorageS3 .networkPolicies.rclone.sync.objectStorage
  fi
  if ! yq_null sc .networkPolicies.rclone.destinationObjectStorageSwift; then
    yq_move sc .networkPolicies.rclone.destinationObjectStorageSwift .networkPolicies.rclone.sync.objectStorageSwift
  fi
  if ! yq_null sc .networkPolicies.rclone.secondaryUrl; then
    yq_move sc .networkPolicies.rclone.secondaryUrl .networkPolicies.rclone.sync.secondaryUrl
  fi
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "no operation on workload cluster"
fi
