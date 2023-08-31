#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info " - move .sync.type to .sync.destinationType"
yq_move sc .objectStorage.sync.type .objectStorage.sync.destinationType
