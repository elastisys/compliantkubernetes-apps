#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if ! yq_null sc .fluentd; then
  log_info "- sc: reconfigure"

  if yq_null sc .fluentd.enabled.scLogs; then
    yq_copy sc .fluentd.enabled .fluentd.scLogs.enabled
  fi
  yq_move sc .fluentd.forwarder.chunkLimitSize .fluentd.forwarder.buffer.chunkLimitSize
  yq_move sc .fluentd.forwarder.totalLimitSize .fluentd.forwarder.buffer.totalLimitSize
  yq_remove sc .fluentd.forwarder.livenessProbe
  yq_remove sc .fluentd.forwarder.readinessProbe
  yq_remove sc .fluentd.forwarder.useRegionEndpoint
fi
if ! yq_null wc .fluentd; then
  log_info "- wc: reconfigure"

  yq_move wc .fluentd.elasticsearch.buffer .fluentd.forwarder.buffer
  yq_move wc .fluentd.resources .fluentd.forwarder.resources
  yq_move wc .fluentd.tolerations .fluentd.forwarder.tolerations
  yq_move wc .fluentd.nodeSelector .fluentd.forwarder.nodeSelector
  yq_move wc .fluentd.affinity .fluentd.forwarder.affinity
fi

log_warn "Fluentd can now collect audit logs by setting \"fluentd.audit.enabled\""
