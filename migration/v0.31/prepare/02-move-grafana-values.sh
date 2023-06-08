#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "- move grafana config"

if yq_null sc .grafana.user; then
  yq_move sc .user.grafana .grafana.user
fi
if yq_null sc .grafana.ops; then
  yq_move sc .prometheus.grafana .grafana.ops
fi
if yq_check sc .user {}; then
  yq_remove sc .user
fi
if yq_check sc .prometheus {}; then
  yq_remove sc .prometheus
fi
