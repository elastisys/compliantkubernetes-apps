#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

log_info "- ensure .opa.enabled is removed"
yq_remove common .opa.enabled
yq_remove sc .opa.enabled
yq_remove wc .opa.enabled
