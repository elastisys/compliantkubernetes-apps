#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?"CK8S_CONFIG_PATH is unset"}"

config_common="$CK8S_CONFIG_PATH/common-config.yaml"
config_sc="$CK8S_CONFIG_PATH/sc-config.yaml"
config_wc="$CK8S_CONFIG_PATH/wc-config.yaml"

annotation_string_to_map() {
    annotation=$(yq4 '.ingressNginx.controller.service.annotations' "${1}")
    if [[ "${annotation}" == "null" ]]; then
        echo "info: .ingressNginx.controller.service.annotations missing from ${1}, skipping."
    else
        echo "info: Converting annotations to map for ${1}"

        key=$(echo "${annotation}" | yq4 'keys | .[]')
        value=$(echo "${annotation}" | yq4 '.[]')

        yq4 -i 'del(.ingressNginx.controller.service.annotations)' "${1}"
        yq4 -i ".ingressNginx.controller.service.annotations.\"${key}\" = \"${value}\"" "${1}"
    fi
}

annotation_string_to_map "${config_common}"
annotation_string_to_map "${config_sc}"
annotation_string_to_map "${config_wc}"
