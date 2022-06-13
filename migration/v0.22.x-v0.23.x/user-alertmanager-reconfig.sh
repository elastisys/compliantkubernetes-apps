#!/usr/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

alertmanager_config_bk="${CK8S_CONFIG_PATH}/user-alertmanager.yaml.bk"
alertmanager_config_new="${CK8S_CONFIG_PATH}/user-alertmanager.yaml"
common_config="${CK8S_CONFIG_PATH}/common-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"

cleanup(){
  echo -n "Do you want to remove the user-alertmanager config backups? [y/N]: "
  read -r reply
  if [[ "${reply}" == "y" ]]; then
      rm "$@"
  fi
}

if [[ ! -f "${common_config}" ]]; then
    echo "Override common-config does not exist, aborting."
    exit 1
elif [[ ! -f "${wc_config}" ]]; then
    echo "Override wc-config does not exist, aborting."
    exit 1
fi

wc=$(yq m -x -a overwrite -j "${common_config}" "${wc_config}" | yq r - 'user.alertmanager')

if [[ $(yq r <(echo "${wc}") 'enabled') != "true" ]]; then
    echo "User Alertmanager is not enabled, skipping."
    exit 0
fi

echo "Saving existing configuration for user-alertmanager"

"${here}/../../bin/ck8s" ops kubectl wc -n alertmanager get secret alertmanager-alertmanager -o "jsonpath='{.data.alertmanager\.yaml}'" | base64 -d > "${alertmanager_config_bk}"

echo "A backup was created here: ${alertmanager_config_bk}"

default_receiver=$(yq r "${alertmanager_config_bk}" 'route.receiver')
default_slack_url=$(yq r "${alertmanager_config_bk}" 'receivers.*.slack_configs.*.api_url')

if [[ "${default_receiver}" == 'slack' && "${default_slack_url}" == 'https://alertmanagerwebhook.example.com' ]]; then
    echo "Changing the default slack receiver to null."
    cp "${alertmanager_config_bk}" "${alertmanager_config_new}"
    yq w -i --style single "${alertmanager_config_new}" 'route.receiver' 'null'

    echo "Applying the new user-alertmanager config."
    "${here}/../../bin/ck8s" ops kubectl wc -n alertmanager patch secret alertmanager-alertmanager -p "'{\"data\":{\"alertmanager.yaml\":\"$(base64 -w 0 < "${alertmanager_config_new}")\"}}'"
    cleanup "${alertmanager_config_bk}" "${alertmanager_config_new}"
else
    echo "The default receiver has already been changed, skipping."
    cleanup "${alertmanager_config_bk}"
    exit 0
fi
