#!/usr/bin/env bash

set -euo pipefail

export CK8S_STACK="migration/delete-user-alertmanager"
ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

source "${ROOT}/scripts/migration/lib.sh"

# Load workload cluster config (wc)
config_load wc

log_info "Checking for 'user-alertmanager' Helm release in workload cluster..."

if helmfile_list wc name=user-alertmanager | grep -q 'user-alertmanager'; then
  log_info "Deleting 'user-alertmanager' Helm release..."
  helmfile_destroy wc name=user-alertmanager
  log_info "user-alertmanager Helm release deleted successfully."
else
  log_warn "user-alertmanager Helm release not found. Skipping."
fi
