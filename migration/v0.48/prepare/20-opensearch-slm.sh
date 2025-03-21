#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "operation on service cluster"
  yq_remove sc '.opensearch.snapshot.ageSeconds'
  yq_remove sc '.opensearch.snapshot.maxRequestSeconds'
  yq_remove sc '.opensearch.snapshot.retentionStartingDeadlineSeconds'
  yq_remove sc '.opensearch.snapshot.retentionActiveDeadlineSeconds'
  yq_remove sc '.opensearch.snapshot.retentionResources'
fi
