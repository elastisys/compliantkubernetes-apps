#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "Moving current Opensearch configuration to override config"
  yq_add sc .opensearch "$(yq_merge "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml" "${CK8S_CONFIG_PATH}/sc-config.yaml" "${CK8S_CONFIG_PATH}/common-config.yaml" | yq4 -o json .opensearch)"
fi
