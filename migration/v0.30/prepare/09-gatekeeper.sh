#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "- ensure .opa.enabled is removed"
yq_remove common .opa.enabled
yq_remove sc .opa.enabled
yq_remove wc .opa.enabled

if ! yq_null wc .opa.imageRegistry.URL && yq_null common .opa.imageRegistry.URL; then
  log_info "- move .opa.imageRegistry.URL to common"

  log_info "  - reading wc"
  img="$(yq4 -oj -I0 ".opa.imageRegistry.URL" "${CK8S_CONFIG_PATH}/wc-config.yaml")"

  log_info "  - writing common"
  yq4 -i -P ".opa.imageRegistry.URL = ${img}" "${CK8S_CONFIG_PATH}/common-config.yaml"

  # Clean up done by init
fi
