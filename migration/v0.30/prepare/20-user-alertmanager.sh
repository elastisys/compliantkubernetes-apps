#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if ! yq_null wc .user.alertmanager.enabled; then
  if yq_check wc .user.alertmanager.enabled false; then
    log_info "- common: disable user.alertmanager in overwrite common-config"
    yq_add common .user.alertmanager.enabled false
  fi
else
  log_info "- common: no changes, exiting"
fi
