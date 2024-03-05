#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "Configuring HNC webhook"

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "- Operating on wc-config"
  log_info "- Checking Kubernetes version"
  minor_version=$(kubectl_do wc version -ojson | jq -r .serverVersion.minor)
  if [[ $minor_version -gt 27 ]]; then
    log_info "- minor version is $minor_version"
    yq_add wc .hnc.webhookMatchConditions true
  fi
fi
