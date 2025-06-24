#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# move_net_plugin <cluster>
move_net_plugin() {
  local cluster
  cluster="${1}"

  log_info "Running calico config migration in ${cluster}-config..."

  yq_move "${cluster}" '.calicoAccountant' '.networkPlugin.calico.calicoAccountant'
  yq_move "${cluster}" '.calicoFelixMetrics' '.networkPlugin.calico.calicoFelixMetrics'
}

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  move_net_plugin sc
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  move_net_plugin wc
fi
move_net_plugin common
