#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|wc|both)$ ]]; then
  service_enabled=$(yq_dig common .ingressNginx.controller.service.enabled)
  if [[ "${service_enabled}" != "true" ]]; then
    log_info "ingress-nginx service not enabled, skipping"
    exit 0
  fi

  annotations=$(yq_dig common .ingressNginx.controller.service.annotations)
  if [[ ! "${annotations}" =~ ^set\-me ]]; then
    log_info "ingress-nginx annotations are already set, skipping"
    exit 0
  fi

  log_info "setting ingress-nginx annotations to empty object"
  yq_add common .ingressNginx.controller.service.annotations {}
fi
