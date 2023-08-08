#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "- check if the rclone-sync networkPolicy exists in sc-config"
if ! yq_null sc .networkPolicies.rcloneSync.destinationObjectStorage; then
  log_info "- changing rclone-sync networkPolicy name to destinationObjectStorageS3"
  yq4 -i 'with(.networkPolicies.rcloneSync; with_entries(.key |= . + "S3" ))' "${CK8S_CONFIG_PATH}/sc-config.yaml"
else
  log_info "- no changes necessary"
fi
