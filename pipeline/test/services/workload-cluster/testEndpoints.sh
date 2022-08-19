#!/bin/bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/funcs.sh
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

echo
echo
echo "Testing endpoints"
echo "=================="

base_domain=$(yq4 -e '.global.baseDomain' "${CONFIG_FILE}")
enable_user_alertmanager_ingress=$(yq4 -e '.user.alertmanager.ingress.enabled' "${CONFIG_FILE}")
enable_user_alertmanager=$(yq4 -e '.user.alertmanager.enabled' "${CONFIG_FILE}")

if [[ "${enable_user_alertmanager_ingress}" == "true" && "${enable_user_alertmanager}" == "true" ]]
then
    testEndpoint Alertmanager-user "https://alertmanager.${base_domain}/"
fi

echo
echo
echo "Testing endpoints protection"
echo "============================="

if [[ "${enable_user_alertmanager_ingress}" == "true" && "${enable_user_alertmanager}" == "true" ]]
then
    testEndpointProtected Alertmanager-user "https://alertmanager.${base_domain}/" 401
fi
