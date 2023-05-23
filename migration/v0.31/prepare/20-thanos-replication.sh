#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

yq_move sc '.thanos.receiver.replicationFactor' '.thanos.receiveDistributor.replicationFactor'
