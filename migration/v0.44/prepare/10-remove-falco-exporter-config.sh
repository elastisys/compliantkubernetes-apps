#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "operation on service cluster"
  yq_remove sc .falco.falcoExporter
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  log_info "operation on workload cluster"
  yq_remove wc .falco.falcoExporter
fi

yq_remove common .falco.falcoExporter
