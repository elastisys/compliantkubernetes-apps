#!/usr/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

wc_defaults="${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"

if [[ ! -f "${wc_defaults}" ]]; then
    echo "Default wc-config does not exist, aborting."
    exit 1
elif [[ ! -f "${wc_config}" ]]; then
    echo "Override wc-config does not exist, aborting."
    exit 1
fi

wc=$(yq m -x -a overwrite -j "${wc_defaults}" "${wc_config}" | yq r - 'user.alertmanager')

if [[ $(yq r <(echo "${wc}") 'enabled') != "true" ]]; then
    echo "User Alertmanager is not enabled, skipping."
    exit 0
fi

"${here}/../../bin/ck8s" ops helmfile wc -l app=user-alertmanager -n "$(yq r <(echo "${wc}") 'namespace')" -i destroy

if [[ $(yq r <(echo "${wc}") 'namespace') == "alertmanager" ]]; then
    echo -n "--- alertmanager namespace must be recreated
    bin/ck8s ops kubectl wc delete namespace alertmanager
    - continue? [y/N]: "
    read -r reply
    if [[ "${reply}" != "y" ]]; then
        echo "aborting"
        exit 1
    fi

    "${here}/../../bin/ck8s" ops kubectl wc delete namespace alertmanager
fi

"${here}/../../bin/ck8s" bootstrap wc

"${here}/../../bin/ck8s" ops helmfile wc -l app=user-rbac -i sync

"${here}/../../bin/ck8s" ops helmfile wc -l app=user-alertmanager -i apply
