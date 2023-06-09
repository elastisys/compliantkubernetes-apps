#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# Note: 00-template.sh will be skipped by the upgrade command
log_info "- move rookCeph monitoring and Gatekeeper PSP keys"

if ! yq_null common .monitoring.rook.enabled; then
  log_info "- move .monitoring.rook.enabled .rookCeph.monitoring.enabled"

  yq_move common .monitoring.rook.enabled .rookCeph.monitoring.enabled
  yq_remove common .monitoring
fi

if ! yq_null common .rookCeph.enabled; then
  log_info "- move .rookCeph.enabled .rookCeph.gatekeeperPsp.enabled"

  yq_move common .rookCeph.enabled .rookCeph.gatekeeperPsp.enabled
fi
