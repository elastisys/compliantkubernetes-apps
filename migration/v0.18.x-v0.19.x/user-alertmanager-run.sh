#!/usr/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

common_defaults="${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
common_config="${CK8S_CONFIG_PATH}/common-config.yaml"
wc_defaults="${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"
sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"

if [[ ! -f "${common_defaults}" ]]; then
    echo "Default common-config does not exist, aborting."
    exit 1
elif [[ ! -f "${common_config}" ]]; then
    echo "Override common-config does not exist, aborting."
    exit 1
elif [[ ! -f "${wc_defaults}" ]]; then
    echo "Default wc-config does not exist, aborting."
    exit 1
elif [[ ! -f "${wc_config}" ]]; then
    echo "Override wc-config does not exist, aborting."
    exit 1
fi

wc=$(yq m -x -a overwrite -j "${common_defaults}" "${wc_defaults}" "${common_config}" "${wc_config}" | yq r - 'user.alertmanager')

if [[ $(yq r <(echo "${wc}") 'enabled') != "true" ]]; then
    echo "User Alertmanager is not enabled, skipping."
    exit 0
fi

prompt() {
    echo -n "- continue? [y/N]: "
    read -r reply
    if [[ "${reply}" != "y" ]]; then
        echo "aborting"
        exit 1
    fi
}

echo "--- remove user alertmanager"
prompt

"${here}/../../bin/ck8s" ops helmfile wc -l app=user-alertmanager -n "$(yq r <(echo "${wc}") 'namespace')" destroy

if [[ $(yq r <(echo "${wc}") 'namespace') == "alertmanager" ]]; then
    echo -e "\n--- recreate 'alertmanager' namespace, this will delete it and all resources in it"
    prompt

    echo -e "\n--- remove 'alertmanager' from 'user.namespaces'"
    prompt

    yq d -i "${wc_config}" 'user.namespaces(.==alertmanager)'

    echo -e "\n--- remove 'alertmanager' namespace"
    prompt

    "${here}/../../bin/ck8s" ops helmfile wc -l app=user-rbac -i sync
    "${here}/../../bin/ck8s" ops kubectl wc delete namespace alertmanager --ignore-not-found=true
fi

echo -e "\n--- create 'alertmanager' namespace"
"${here}/../../bin/ck8s" bootstrap wc

echo -e "\n--- deploy user alertmanager"
"${here}/../../bin/ck8s" ops helmfile wc -l app=user-alertmanager -i apply

echo -e "\n--- remove deprecated option 'user.alertmanager.namespace'"
prompt

clear_ns() {
    yq d -i "$1" 'user.alertmanager.namespace'
    if [[ "$(yq r "$1" 'user.alertmanager')" == '{}' ]]; then
        yq d -i "$1" 'user.alertmanager'
    fi
}

clear_ns "${common_config}"
clear_ns "${wc_config}"
if [[ -f "${sc_config}" ]]; then
  clear_ns "${sc_config}"
fi
