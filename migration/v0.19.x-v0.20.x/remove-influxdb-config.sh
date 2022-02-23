#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"
secrets="${CK8S_CONFIG_PATH}/secrets.yaml"
common_config="${CK8S_CONFIG_PATH}/common-config.yaml"
sops_config="${CK8S_CONFIG_PATH}/.sops.yaml"
secrets_tmp="/tmp/secret.yaml"
delete_value() {
    value=$(yq r "${1}" "${2}")

    if [[ -z "${value}" ]]; then
        echo "${2} missing from config, skipping."
    else
        yq d -i "${1}" "${2}"
    fi
}

if [[ ! -f "${sc_config}" ]]; then
    echo "Sc-config does not exist, skipping."
    exit 0
fi

if [[ ! -f "${wc_config}" ]]; then
    echo "Wc-config does not exist, skipping."
    exit 0
fi

delete_value "${sc_config}" 'influxDB'
delete_value "${wc_config}" 'influxDB'
delete_value "${common_config}" 'influxDB'
sops -d "${secrets}" | \
  yq d - 'influxDB' | \
  sops --config "${sops_config}" --input-type=yaml --output-type=yaml -e /dev/stdin > "${secrets_tmp}"

mv "${secrets_tmp}" "${secrets}"

sops -d "${secrets}" | \
  yq d - 'prometheus' | \
  sops --config "${sops_config}" --input-type=yaml --output-type=yaml -e /dev/stdin > "${secrets_tmp}"

mv "${secrets_tmp}" "${secrets}"
