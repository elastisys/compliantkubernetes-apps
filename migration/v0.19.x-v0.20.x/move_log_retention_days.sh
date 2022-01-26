#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"

move_value_to() {
    value=$(yq r "${sc_config}" "$1")

    if [[ -z "${value}" ]]; then
        echo "$1 missing from sc-config, skipping."
    else
        yq w -i "${sc_config}" "$2" "${value}"

    fi
}

delete_value() {
    value=$(yq r "${sc_config}" "$1")

    if [[ -z "${value}" ]]; then
        echo "$1 missing from sc-config, skipping."
    else
        yq d -i "${sc_config}" "$1"
    fi
}

if [[ ! -f "${sc_config}" ]]; then
    echo "Sc-config does not exist, skipping."
    exit 0
fi

move_value_to 'logRetention.days' 'fluentd.scLogsRetention.days'
delete_value 'logRetention'
