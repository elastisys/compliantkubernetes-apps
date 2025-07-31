#!/usr/bin/env bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/funcs.sh
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

harborEnabled=$(yq -e '.harbor.enabled' "${CONFIG_FILE}")
harborPassword=$(sops -d "${CK8S_CONFIG_PATH}/secrets.yaml" | yq '.harbor.password')
harborDomain=$(yq '.harbor.subdomain + "." + .global.baseDomain' "${CONFIG_FILE}")
dexDomain=$(yq '.dex.subdomain + "." + .global.baseDomain' "${CONFIG_FILE}")

[[ "$harborEnabled" == "true" ]] || exit

harbor_check_oidc_endpoint() {
  echo -ne "Checking if harbor oidc_endpoint has been configured by the init-harbor job ... "
  local -r endpoint="$(curl -s -u "admin:${harborPassword}" "https://$harborDomain/api/v2.0/configurations" | jq -r '.oidc_endpoint.value')"
  if [[ -n "$dexDomain" && "$endpoint" == *"$dexDomain" ]]; then
    echo -e "success ✔"
  else
    echo -e "failure ❌"
  fi
}

echo
echo
echo "Testing harbor"
echo "===================="
harbor_check_oidc_endpoint
