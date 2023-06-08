#!/bin/bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/funcs.sh
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

echo
echo
echo "Testing endpoints"
echo "=================="

ops_domain=$(yq4 -e '.global.opsDomain' "${CONFIG_FILE}")
base_domain=$(yq4 -e '.global.baseDomain' "${CONFIG_FILE}")
enable_harbor=$(yq4 -e '.harbor.enabled' "${CONFIG_FILE}")
enable_user_grafana=$(yq4 -e '.grafana.user.enabled' "${CONFIG_FILE}")
grafana_subdomain=$(yq4 -e '.grafana.user.subdomain' "${CONFIG_FILE}")
grafana_ops_subdomain=$(yq4 -e '.grafana.ops.subdomain' "${CONFIG_FILE}")
harbor_subdomain=$(yq4 -e '.harbor.subdomain' "${CONFIG_FILE}")
opensearch_subdomain=$(yq4 -e '.opensearch.subdomain' "${CONFIG_FILE}")
opensearch_dashboards_subdomain=$(yq4 -e '.opensearch.dashboards.subdomain' "${CONFIG_FILE}")
thanos_subdomain=$(yq4 -e '.thanos.receiver.subdomain' "${CONFIG_FILE}")
enable_thanos=$(yq4 -e '.thanos.enabled' "${CONFIG_FILE}")
enable_thanos_receiver=$(yq4 -e '.thanos.receiver.enabled' "${CONFIG_FILE}")

testEndpoint OpenSearch "https://${opensearch_subdomain}.${ops_domain}/"

testEndpoint OpenSearchDashboards "https://${opensearch_dashboards_subdomain}.${base_domain}/"

if [ "$enable_harbor" == true ]; then
    testEndpoint Harbor "https://${harbor_subdomain}.${base_domain}/"
fi

testEndpoint Grafana "https://${grafana_ops_subdomain}.${ops_domain}/"

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

testEndpointProtected OpenSearch "https://${opensearch_subdomain}.${ops_domain}/" 401

testEndpointProtected OpenSearchDashboards "https://${opensearch_dashboards_subdomain}.${base_domain}/" 302

if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_receiver}" == "true" ]]; then
    testEndpointProtected ThanosReceiver "https://${thanos_subdomain}.${ops_domain}/" 401
fi
