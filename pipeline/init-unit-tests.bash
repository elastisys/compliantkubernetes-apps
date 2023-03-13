#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
ck8s="${here}/../bin/ck8s"
# shellcheck source=pipeline/common.bash
source "${here}/common.bash"

export CK8S_FLAVOR="${CI_CK8S_FLAVOR:-dev}"
export CK8S_ENVIRONMENT_NAME="${CK8S_ENVIRONMENT_NAME:-apps-${CK8S_CLOUD_PROVIDER}-${CK8S_FLAVOR}-${GITHUB_RUN_ID}}"

# Initialize ck8s repository

if [[ "${CI:-}" == "true" ]]; then
 	git config --global --add safe.directory /github/workspace

  if [[ -f "${CK8S_CONFIG_PATH}/secrets.yaml" ]]; then
    yq4 -i ".creation_rules = [{\"pgp\": \"${CK8S_PGP_FP}\"}]" "${CK8S_CONFIG_PATH}/.sops.yaml"

    if ! grep -qs "sops:\\|\"sops\":\\|\\[sops\\]\\|sops_version=" "${CK8S_CONFIG_PATH}/secrets.yaml"; then
      sops --config "${CK8S_CONFIG_PATH}/.sops.yaml" -e -i "${CK8S_CONFIG_PATH}/secrets.yaml"
    fi
  fi
fi

"${ck8s}" init

# Add additional config changes here
config_update "common" ".issuers.letsencrypt.staging.email" "me@example.com"
config_update "common" ".issuers.letsencrypt.prod.email" "me@example.com"

config_update "common" ".objectStorage.type" "s3"
config_update "common" ".objectStorage.s3.forcePathStyle" "true"
config_update "common" ".objectStorage.s3.region" "unit-region"
config_update "common" ".objectStorage.s3.regionAddress" "unit-regionAddress"
config_update "common" ".objectStorage.s3.regionEndpoint" "unit-regionEndpoint"

config_update "sc" ".objectStorage.s3.accessKey" "unit-accessKey"
config_update "sc" ".objectStorage.s3.secretKey" "unit-secretKey"

if [[ "${CK8S_CLOUD_PROVIDER}" = "citycloud" ]]; then
  config_update "sc" ".objectStorage.swift.authVersion" "0"
  config_update "sc" ".objectStorage.swift.authUrl" "https://unit-authUrl.example.com:5000"
  config_update "sc" ".objectStorage.swift.region" "unit-region"
  config_update "sc" ".objectStorage.swift.domainId" "unit-domainId"
  config_update "sc" ".objectStorage.swift.projectDomainId" "unit-projectDomainId"
  config_update "sc" ".objectStorage.swift.projectId" "unit-projectId"
  config_update "sc" ".objectStorage.swift.username" "unit-username"
  config_update "sc" ".objectStorage.swift.password" "unit-password"
fi

config_update "wc" ".falco.alerts.enabled" "true"
config_update "wc" ".objectStorage.s3.accessKey" "unit-accessKey"
config_update "wc" ".objectStorage.s3.secretKey" "unit-secretKey"
