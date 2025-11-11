#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

module_maintenance_test "${CK8S_CLUSTER}" app=node-local-dns "${HERE}/module-accepted-changes/node-local-dns"
