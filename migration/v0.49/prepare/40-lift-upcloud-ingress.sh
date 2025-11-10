#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

lift_ingress() {
  host_port="$(yq_dig "${1}" '.ingressNginx.controller.useHostPort')"
  if [[ "${host_port}" == "true" ]]; then
    yq_dig "${1}" '.ingressNginx.controller.useHostPort' "true"
  fi

  service_enabled="$(yq_dig "${1}" '.ingressNginx.controller.service.enabled')"
  if [[ "${service_enabled}" == "false" ]]; then
    yq_dig "${1}" '.ingressNginx.controller.service.enabled' "false"
  fi
}

provider="$(yq '.global.ck8sCloudProvider' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml")"
if [[ "${provider}" == "upcloud" ]]; then
  if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
    lift_ingress sc
  fi
  if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
    lift_ingress wc
  fi
fi
