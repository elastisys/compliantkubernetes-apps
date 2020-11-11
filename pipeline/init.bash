#!/bin/bash

set -eu -o pipefail

# shellcheck disable=SC1090
here="$(dirname "$(readlink -f "$0")")"
ck8s="${here}/../bin/ck8s"
# shellcheck disable=SC1090
source "${here}/common.bash"

export CK8S_FLAVOR="${CI_CK8S_FLAVOR:-dev}"
export CK8S_ENVIRONMENT_NAME="apps-${CK8S_CLOUD_PROVIDER}-${CK8S_FLAVOR}-${GITHUB_RUN_ID}"

# Initialize ck8s repository

"${ck8s}" init

# Update ck8s configuration

case "${CK8S_CLOUD_PROVIDER}" in
    "exoscale")
    for cluster in sc wc; do
        config_update "${cluster}" "global.baseDomain" "${CK8S_ENVIRONMENT_NAME}.a1ck.io"
        config_update "${cluster}" "global.opsDomain" "ops.${CK8S_ENVIRONMENT_NAME}.a1ck.io"
    done
    secrets_update "s3.accessKey" "${CI_EXOSCALE_KEY}"
    secrets_update "s3.secretKey" "${CI_EXOSCALE_SECRET}"
    ;;
    "safespring")
    for cluster in sc wc; do
        config_update "${cluster}" "global.baseDomain" "${CK8S_ENVIRONMENT_NAME}.elastisys.se"
        config_update "${cluster}" "global.opsDomain" "ops.${CK8S_ENVIRONMENT_NAME}.elastisys.se"
    done
    secrets_update "citycloud.username" "${SAFESPRING_OS_USERNAME}"
    secrets_update "citycloud.password" "${SAFESPRING_OS_PASSWORD}"
    secrets_update "s3.accessKey" "${SAFESPRING_S3_ACCESS_KEY}"
    secrets_update "s3.secretKey" "${SAFESPRING_S3_SECRET_KEY}"
    ;;
    "citycloud")
    for cluster in sc wc; do
        config_update "${cluster}" "global.baseDomain" "${CK8S_ENVIRONMENT_NAME}.elastisys.se"
        config_update "${cluster}" "global.opsDomain" "ops.${CK8S_ENVIRONMENT_NAME}.elastisys.se"
    done
    secrets_update "citycloud.username" "${CITYCLOUD_OS_USERNAME}"
    secrets_update "citycloud.password" "${CITYCLOUD_OS_PASSWORD}"
    secrets_update "s3.accessKey" "${CITYCLOUD_S3_ACCESS_KEY}"
    secrets_update "s3.secretKey" "${CITYCLOUD_S3_SECRET_KEY}"
    ;;
esac

# Add additional config changes here
config_update "wc" "falco.alerts.enabled" "true"
