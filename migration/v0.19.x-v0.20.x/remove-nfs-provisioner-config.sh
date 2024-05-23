#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"
common_config="${CK8S_CONFIG_PATH}/common-config.yaml"

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

delete_value "${sc_config}" 'nfsProvisioner'
delete_value "${wc_config}" 'nfsProvisioner'
delete_value "${common_config}" 'nfsProvisioner'
