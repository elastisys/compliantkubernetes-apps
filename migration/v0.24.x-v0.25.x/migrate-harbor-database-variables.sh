#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
secret_config="${CK8S_CONFIG_PATH}/secrets.yaml"
sops_config="${CK8S_CONFIG_PATH}/.sops.yaml"

move_value_to() {
    value=$(yq4 "${1}" "${3}")

    if [[ -z "${value}" ]]; then
        echo "${1} missing from ${3}, skipping."
    else
        yq4 "${1}" "${3}" | yq4 "${2}" - | yq4 eval-all -i 'select(fi == 0) * select(fi == 1)' "${3}" -
    fi
}

delete_value() {
    value=$(yq4 "${1}" "${2}")

    if [[ -z "${value}" ]]; then
        echo "$1 missing from $2, skipping."
    else
        yq4 "del(${1})" -i "$2"
    fi
}

move_value_to '.harbor.database.persistentVolumeClaim' '{"harbor":{"database":{"internal":{"persistentVolumeClaim": . }}}}' "${sc_config}"
move_value_to '.harbor.database.resources' '{"harbor":{"database":{"internal":{"resources": . }}}}' "${sc_config}"
delete_value '.harbor.database.persistentVolumeClaim'  "${sc_config}"
delete_value '.harbor.database.resources' "${sc_config}"

sops --config "${sops_config}" -d -i "${secret_config}"

move_value_to '.harbor.databasePassword' '{"harbor":{"internal": {"databasePassword": . }}}' "${secret_config}"
delete_value '.harbor.databasePassword' "${secret_config}"

XSRF_KEY_LENGTH=$(yq4 '.harbor.xsrf | length' "${secret_config}")
if [ "${XSRF_KEY_LENGTH}" -ne 32 ]; then
    echo "Old xsrf key was not the correct length, updating to a valid one."
    NEW_XSRF_KEY=$(pwgen -cns 32 1)
    yq4 -i '.harbor.xsrf = "'"${NEW_XSRF_KEY}"'"' "${secret_config}"
fi

sops --config "${sops_config}" -e -i "${secret_config}"
