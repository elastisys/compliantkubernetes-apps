#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "- move subdomain values to common"

for field in grafana.ops grafana.user harbor harbor.notary dex opensearch.dashboards; do
  if ! yq_null sc ".${field}.subdomain" && yq_null common ".${field}.subdomain" ; then
    yq_move_to_file sc ".${field}.subdomain" common ".${field}.subdomain"
  fi
done

log_info "- move harbor enabled to common"

if ! yq_null sc ".harbor.enabled" && yq_null common ".harbor.enabled" ; then
  yq_move_to_file sc ".harbor.enabled" common ".harbor.enabled"
fi
