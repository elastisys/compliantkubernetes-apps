#!/usr/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

wc_defaults="${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"

am_config="${CK8S_CONFIG_PATH}/alertmanager.yaml"
am_users="${CK8S_CONFIG_PATH}/alertmanager.users.json"

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

if [[ -f "${am_config}" ]]; then
    echo "Reconfiguring Alertmanager..."

    "${here}/../../bin/ck8s" ops kubectl wc -n alertmanager get secret alertmanager-alertmanager -o "jsonpath='{.data.alertmanager\.yaml}'" | \
        base64 -d | yq x -C -P - "${am_config}" || true

    echo -n "- continue? (if empty then there is no change) [y/N]: "
    read -r reply
    if [[ "${reply}" != "y" ]]; then
        echo "aborting"
        exit 1
    fi

    "${here}/../../bin/ck8s" ops kubectl wc -n alertmanager patch secret alertmanager-alertmanager -p "'{\"data\":{\"alertmanager.yaml\":\"$(base64 -w 0 < "${am_config}")\"}}'"
    echo

    echo "Do you want to remove the leftover configuration file? (${am_config}) [y/N]: "
    read -r reply
    if [[ "${reply}" == "y" ]]; then
        rm "${am_config}"
    fi
fi

if [[ -f "${am_users}" ]]; then
    echo "Reconfiguring Alertmanager users..."
    "${here}/../../bin/ck8s" ops kubectl wc -n alertmanager get rolebinding alertmanager-configurer -o "jsonpath='{.subjects}'" | \
        yq x -C -P - "${am_users}" || true

    echo -n "- continue? (if empty then there is no change) [y/N]: "
    read -r reply
    if [[ "${reply}" != "y" ]]; then
        echo "aborting"
        exit 1
    fi

    "${here}/../../bin/ck8s" ops kubectl wc -n alertmanager patch rolebinding alertmanager-configurer -p "'{\"subjects\":$(cat "${am_users}")}'"
    echo

    echo "Do you want to remove the leftover configuration file? (${am_users}) [y/N]: "
    read -r reply
    if [[ "${reply}" == "y" ]]; then
        rm "${am_users}"
    fi
fi
