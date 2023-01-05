#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?"CK8S_CONFIG_PATH is unset"}"

config_sc="$CK8S_CONFIG_PATH/sc-config.yaml"

port_to_array() {
    port=$(yq4 '.networkPolicies.harbor.jobservice.port' "${1}")
    if [[ "${port}" == "null" ]]; then
        echo "info: .networkPolicies.harbor.jobservice.port missing from ${1}, skipping."
    else
        echo "info: Converting port to array for ${1}"

        yq4 -i 'del(.networkPolicies.harbor.jobservice.port)' "${1}"
        yq4 -i ".networkPolicies.harbor.jobservice.ports[0] = ${port}" "${1}"
    fi
}

port_to_array "${config_sc}"
