#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "Removing deprecated Harbor Notary config"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  yq_remove common .harbor.notary
  yq_remove sc .harbor.database.external.notaryServerDatabase
  yq_remove sc .harbor.database.external.notarySignerDatabase
  yq_remove sc .harbor.notary
  yq_remove sc .harbor.notarySigner
fi
