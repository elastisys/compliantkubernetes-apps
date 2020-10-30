#!/bin/bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC1090
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

echo
echo
echo "Testing endpoints"
echo "=================="

ops_domain=$(yq r -e "${CONFIG_FILE}" 'global.opsDomain')
base_domain=$(yq r -e "${CONFIG_FILE}" 'global.baseDomain')
enable_harbor=$(yq r -e "${CONFIG_FILE}" 'harbor.enabled')
enable_ck8sdash=$(yq r -e "${CONFIG_FILE}" 'ck8sdash.enabled')
enable_user_grafana=$(yq r -e "${CONFIG_FILE}" 'user.grafana.enabled')

testEndpoint Elasticsearch "https://elastic.${ops_domain}/"

testEndpoint Kibana "https://kibana.${base_domain}/"

if [ "$enable_harbor" == true ]; then
    testEndpoint Harbor "https://harbor.${base_domain}/"
fi

testEndpoint Grafana "https://grafana.${ops_domain}/"

if [ "$enable_ck8sdash" == true ]; then
    testEndpoint ck8sdash "https://ck8sdash.${ops_domain}/"
fi

if [ "$enable_user_grafana" == "true" ]
then
    testEndpoint Grafana-user "https://grafana.${base_domain}/"
fi

echo
echo
echo "Testing endpoints protection"
echo "============================="

if [ "$enable_harbor" == true ]; then
    testEndpointProtected Harbor "https://harbor.${base_domain}/api/v2.0/users" 401
fi


if [ "$enable_user_grafana" == "true" ]
then
    testEndpointProtected Grafana-user "https://grafana.${base_domain}/admin/users" 302
fi

testEndpointProtected Grafana "https://grafana.${ops_domain}/" 302

testEndpointProtected Elasticsearch "https://elastic.${ops_domain}/" 401

testEndpointProtected Kibana "https://kibana.${base_domain}/" 302
