#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq_copy common '.networkPolicies.ingressNginx.ingressOverride.ips' '.networkPolicies.global.scIngress.ips'
yq_copy common '.networkPolicies.ingressNginx.ingressOverride.ips' '.networkPolicies.global.wcIngress.ips'

yq_remove common '.networkPolicies.ingressNginx'
