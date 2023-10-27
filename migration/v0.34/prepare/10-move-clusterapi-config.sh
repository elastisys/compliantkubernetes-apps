#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info " - move .global.clusterApi to .clusterApi.enabled"
yq_move common .global.clusterApi .clusterApi.enabled
