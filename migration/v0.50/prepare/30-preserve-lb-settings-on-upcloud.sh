#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "$(yq_dig sc .global.ck8sCloudProvider)" != "upcloud" ]]; then
  exit 0
fi

lift_option() {
  local -r cluster="${1}"
  local -r key="${2}"
  local -r expected="${3}"

  local value
  value="$(yq_dig "${cluster}" "${key}")"
  if [[ "${value}" == "${expected}" ]]; then
    log_info "Lifting '${key}' option for '${cluster}' to '${expected}'"
    yq_add "${cluster}" "${key}" "${expected}"
  fi
}

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  lift_option sc .ingressNginx.controller.service.enabled false
  lift_option sc .ingressNginx.controller.useHostPort true
  log_info "Setting '.networkPolicies.global.ingressUsingHostNetwork' to 'true'"
  yq_add sc .networkPolicies.global.ingressUsingHostNetwork true
fi

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  lift_option wc .ingressNginx.controller.service.enabled false
  lift_option wc .ingressNginx.controller.useHostPort true
  log_info "Setting '.networkPolicies.global.ingressUsingHostNetwork' to 'true'"
  yq_add wc .networkPolicies.global.ingressUsingHostNetwork true
fi
