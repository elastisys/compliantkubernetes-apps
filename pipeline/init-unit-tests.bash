#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
ck8s="${here}/../bin/ck8s"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

export CK8S_FLAVOR="${CI_CK8S_FLAVOR:-dev}"
export CK8S_ENVIRONMENT_NAME="${CK8S_ENVIRONMENT_NAME:-apps-${CK8S_CLOUD_PROVIDER}-${CK8S_FLAVOR}-${GITHUB_RUN_ID}}"

# Initialize ck8s repository

"${ck8s}" init

# Add additional config changes here
config_update "sc" "issuers.letsencrypt.staging.email" "me@example.com"
config_update "sc" "issuers.letsencrypt.prod.email" "me@example.com"
config_update "sc" "objectStorage.type" "s3"
config_update "sc" "objectStorage.s3.forcePathStyle" "true"
config_update "sc" "objectStorage.s3.region" "unit-region"
config_update "sc" "objectStorage.s3.regionAddress" "unit-regionAddress"
config_update "sc" "objectStorage.s3.regionEndpoint" "unit-regionEndpoint"
config_update "sc" "objectStorage.s3.accessKey" "unit-accessKey"
config_update "sc" "objectStorage.s3.secretKey" "unit-secretKey"

config_update "wc" "issuers.letsencrypt.staging.email" "me@example.com"
config_update "wc" "issuers.letsencrypt.prod.email" "me@example.com"
config_update "wc" "falco.alerts.enabled" "true"
