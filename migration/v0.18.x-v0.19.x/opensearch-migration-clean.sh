#!/usr/bin/bash

set -euo pipefail

IFS=$'\n'

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sops_config="${CK8S_CONFIG_PATH}/.sops.yaml"
secrets="${CK8S_CONFIG_PATH}/secrets.yaml"
secrets_tmp="${CK8S_CONFIG_PATH}/secrets_tmp.yaml"
sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"

if [[ ! -f "${sops_config}" ]]; then
    echo "Sops config does not exist, aborting."
    exit 1
elif [[ ! -f "${secrets}" ]]; then
    echo "Secrets does not exist, aborting."
    exit 1
elif [[ ! -f "${sc_config}" ]]; then
    echo "Override sc-config does not exist, aborting."
    exit 1
elif [[ ! -f "${wc_config}" ]]; then
    echo "Override wc-config does not exist, aborting."
    exit 1
fi

echo "This will remove the following from secrets, sc-config and wc-config:"
echo "- 'objectStorage.buckets.elasticsearch'"
echo "- 'kibana.*'"
echo "- 'elasticsearch.*'"
echo "- 'externalTrafficPolicy.whitelistRange.kibana'"
echo "- 'externalTrafficPolicy.whitelistRange.elasticsearch'"
echo
echo -n "- run? [y/N]: "
read -r reply
if [[ "${reply}" != "y" ]]; then
    exit 1
fi

yq d -i "${sc_config}" "kibana"
yq d -i "${sc_config}" "elasticsearch"
yq d -i "${wc_config}" "elasticsearch"

yq d -i "${sc_config}" "objectStorage.buckets.elasticsearch"
if [[ "$(yq r "${sc_config}" "objectStorage.buckets")" == "{}" ]]; then
    yq d -i "${sc_config}" "objectStorage.buckets"
    if [[ "$(yq r "${sc_config}" "objectStorage")" == "{}" ]]; then
        yq d -i "${sc_config}" "objectStorage"
    fi
fi

yq d -i "${sc_config}" "externalTrafficPolicy.whitelistRange.kibana"
yq d -i "${sc_config}" "externalTrafficPolicy.whitelistRange.elasticsearch"
if [[ "$(yq r "${sc_config}" "externalTrafficPolicy.whitelistRange")" == "{}" ]]; then
    yq d -i "${sc_config}" "externalTrafficPolicy.whitelistRange"
    if [[ "$(yq r "${sc_config}" "externalTrafficPolicy")" == "{}" ]]; then
        yq d -i "${sc_config}" "externalTrafficPolicy"
    fi
fi

sops -d "${secrets}" | \
  yq d - 'elasticsearch' | \
  sops --config "${sops_config}" --input-type=yaml --output-type=yaml -e /dev/stdin > "${secrets_tmp}"

mv "${secrets_tmp}" "${secrets}"

echo
echo "Done!"
