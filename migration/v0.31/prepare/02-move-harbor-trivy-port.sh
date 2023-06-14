#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# Note: 00-template.sh will be skipped by the upgrade command
log_info "- move harbor trivy port to ports"

if ! yq_null sc .networkPolicies.harbor.trivy.port; then
  log_info "- move .networkPolicies.harbor.trivy.port .networkPolicies.harbor.trivy.ports[0]"

  yq_move sc .networkPolicies.harbor.trivy.port .networkPolicies.harbor.trivy.ports[0]
  yq_remove sc .networkPolicies.harbor.trivy.port
fi
