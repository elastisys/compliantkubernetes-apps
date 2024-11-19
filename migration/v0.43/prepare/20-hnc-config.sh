#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "operation on workload cluster"
  if ! yq_null wc .hnc.excludedExtraNamespaces; then
    if yq_null wc .hnc.excludedNamespaces; then
      yq_move wc .hnc.excludedExtraNamespaces .hnc.excludedNamespaces
    else
      yq4 -i '.hnc.excludedNamespaces = ((.hnc.excludedExtraNamespaces | explode(.)) + (.hnc.excludedNamespaces | explode(.)))' "$CK8S_CONFIG_PATH"/wc-config.yaml
      yq_remove wc .hnc.excludedExtraNamespaces
    fi
  fi
fi
