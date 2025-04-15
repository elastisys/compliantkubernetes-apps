#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "no operation: this is a test"
