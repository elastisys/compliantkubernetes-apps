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

# Saving the value so it persists after init
yq w "${wc_config}" -i -P "user.alertmanager.namespace" "$(yq r <(echo "${wc}") 'namespace')"

echo "Saving configuration and user role bindings for $(yq r <(echo "${wc}") 'namespace')/alertmanager"

"${here}/../../bin/ck8s" ops kubectl wc -n "$(yq r <(echo "${wc}") 'namespace')" get secret alertmanager-alertmanager -o "jsonpath='{.data.alertmanager\.yaml}'" | base64 -d > "${CK8S_CONFIG_PATH}/alertmanager.yaml"
echo "  ${CK8S_CONFIG_PATH}/alertmanager.yaml"
"${here}/../../bin/ck8s" ops kubectl wc -n "$(yq r <(echo "${wc}") 'namespace')" get rolebinding alertmanager-configurer -o "jsonpath='{.subjects}'" > "${CK8S_CONFIG_PATH}/alertmanager.users.json"
echo "  ${CK8S_CONFIG_PATH}/alertmanager.users.json"
