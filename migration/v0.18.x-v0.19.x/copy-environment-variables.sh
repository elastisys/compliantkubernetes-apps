#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

common_config="${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
sc_config="${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"

read_and_set() {
    value=$(yq r "${sc_config}" "$1")

    if [[ -z "${value}" ]]; then
        echo "$1 missing from sc-config, skipping."
    else
        if [[ -z $(yq r "${common_config}" "$1") ]]; then
            yq w -i "${common_config}" "$1" "${value}"
        else
            echo "$1 already set in common-config, skipping."
        fi
    fi
}

if [[ ! -f "${sc_config}" ]]; then
    echo "Default sc-config does not exist, skipping."
    exit 0
fi
if [[ ! -f "${common_config}" ]]; then
    echo "Default common-config does not exist, creating."
    touch "${common_config}"
else
    echo "Default common-config already exists, continuing."
fi

read_and_set 'global.ck8sCloudProvider'
read_and_set 'global.ck8sEnvironmentName'
read_and_set 'global.ck8sFlavor'
