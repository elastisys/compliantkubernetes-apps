#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

update_falco_driver() {
  local -r cluster="${1}"
  local current_driver
  current_driver="$(yq_dig "${cluster}" '.falco.driver.kind')"

  if [[ "${current_driver}" == "modern-bpf" ]] || [[ "${current_driver}" == "kmod" ]]; then
    log_info "Updating falco driver from ${current_driver} to modern_ebpf in ${cluster}-config..."
    yq_add "${cluster}" '.falco.driver.kind' '"modern_ebpf"'
  fi
}

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  update_falco_driver sc
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  update_falco_driver wc
fi
update_falco_driver common
