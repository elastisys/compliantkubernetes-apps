#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq_move common '.velero.restic' '.velero.nodeAgent'
yq_move sc '.velero.restic' '.velero.nodeAgent'
yq_move wc '.velero.restic' '.velero.nodeAgent'
