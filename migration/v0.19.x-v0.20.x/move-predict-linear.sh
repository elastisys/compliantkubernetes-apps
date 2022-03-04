#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"
common_config="${CK8S_CONFIG_PATH}/common-config.yaml"

move_value_to() {
    lenght=$(yq r "$3" --length "$1")
    value=$(yq r "$3" "$1")

    if [[ -z "${lenght}" ]]; then
        echo "$1 missing from $3, skipping."
    elif [[ "${lenght}" -eq 0 ]]; then
        yq w -i "$3" "prometheus.predictLinear.enabled" false
    else
        yq w -i "$3" "$2" "${value}"
    fi
}

delete_value() {
    lenght=$(yq r "$2" --length "$1")

    if [[ -z "${lenght}" ]]; then
        echo "$1 missing from $2, skipping."
    else
        yq d -i "$2" "$1"
    fi
}

for i in ${sc_config} ${wc_config} ${common_config}
do
    if [[ ! -f "$i" ]]; then
        echo "$i does not exist, skipping."
    else
       move_value_to 'prometheus.predictLinearLimit' 'prometheus.predictLinear.limit' "$i"
       delete_value 'prometheus.predictLinearLimit' "$i"
    fi
done
