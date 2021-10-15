#!/bin/bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/funcs.sh
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

echo
echo
echo "Testing endpoints"
echo "=================="

ops_domain=$(yq r -e "${CONFIG_FILE}" 'global.opsDomain')
base_domain=$(yq r -e "${CONFIG_FILE}" 'global.baseDomain')
enable_harbor=$(yq r -e "${CONFIG_FILE}" 'harbor.enabled')
enable_user_grafana=$(yq r -e "${CONFIG_FILE}" 'user.grafana.enabled')
grafana_subdomain=$(yq r -e "${CONFIG_FILE}" 'user.grafana.subdomain')
grafana_ops_subdomain=$(yq r -e "${CONFIG_FILE}" 'prometheus.grafana.subdomain')
harbor_subdomain=$(yq r -e "${CONFIG_FILE}" 'harbor.subdomain')
kibana_subdomain=$(yq r -e "${CONFIG_FILE}" 'kibana.subdomain')
elasticsearch_subdomain=$(yq r -e "${CONFIG_FILE}" 'elasticsearch.subdomain')
influxdb_subdomain=$(yq r -e "${CONFIG_FILE}" 'influxDB.subdomain')

testEndpoint Elasticsearch "https://${elasticsearch_subdomain}.${ops_domain}/"

testEndpoint Kibana "https://${kibana_subdomain}.${base_domain}/"

if [ "$enable_harbor" == true ]; then
    testEndpoint Harbor "https://${harbor_subdomain}.${base_domain}/"
fi

testEndpoint Grafana "https://${grafana_ops_subdomain}.${ops_domain}/"
testEndpoint InfluxDB "https://${influxdb_subdomain}.${ops_domain}/health"

if [ "$enable_user_grafana" == "true" ]
then
    testEndpoint Grafana-user "https://${grafana_subdomain}.${base_domain}/"
fi

echo
echo
echo "Testing endpoints protection"
echo "============================="

if [ "$enable_harbor" == true ]; then
    testEndpointProtected Harbor "https://${harbor_subdomain}.${base_domain}/api/v2.0/users" 401
fi


if [ "$enable_user_grafana" == "true" ]
then
    testEndpointProtected Grafana-user "https://${grafana_subdomain}.${base_domain}/admin/users" 302
fi

testEndpointProtected Grafana "https://${grafana_ops_subdomain}.${ops_domain}/" 302

testEndpointProtected Elasticsearch "https://${elasticsearch_subdomain}.${ops_domain}/" 401

testEndpointProtected Kibana "https://${kibana_subdomain}.${base_domain}/" 302
