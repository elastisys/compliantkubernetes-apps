#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

using_host_network=$(yq_dig common '.networkPolicies.global.ingressUsingHostNetwork')
external_load_balancer=$(yq_dig common '.networkPolicies.global.externalLoadBalancer')

if [[ "${using_host_network}" == "true" ]]; then
  yq_add common '.networkPolicies.global.ingressMode' "\"HostNetwork\""
elif [[ "${external_load_balancer}" == "true" ]]; then
  yq_add common '.networkPolicies.global.ingressMode' "\"ExternalProxy\""
fi

yq_remove common '.networkPolicies.global.ingressUsingHostNetwork'
yq_remove common '.networkPolicies.global.externalLoadBalancer'
