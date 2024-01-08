#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  if ! yq_null sc .trivy.resources.limits.memory; then
    size=$(yq4 '.trivy.resources.limits.memory | select(. == "*Mi") | sub("Mi","")' "${CK8S_CONFIG_PATH}/sc-config.yaml")
    if [ -n "$size" ] && ((size < 500)); then
      log_info "- increase the trivy memory limit on sc to 500Mi"
      yq4 -i '.trivy.resources.limits.memory = "500Mi"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
    fi
  fi
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  if ! yq_null wc .trivy.resources.limits.memory; then
    size=$(yq4 '.trivy.resources.limits.memory | select(. == "*Mi") | sub("Mi","")' "${CK8S_CONFIG_PATH}/wc-config.yaml")
    if [ -n "$size" ] && ((size < 500)); then
      log_info "- increase the trivy memory limit on wc to 500Mi"
      yq4 -i '.trivy.resources.limits.memory = "500Mi"' "${CK8S_CONFIG_PATH}/wc-config.yaml"
    fi
  fi
fi
