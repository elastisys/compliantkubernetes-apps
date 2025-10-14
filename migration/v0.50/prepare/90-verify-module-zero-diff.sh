#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

crossplane_diff "${CK8S_CLUSTER}" node-local-dns "${HERE}/module-accepted-changes/node-local-dns"
