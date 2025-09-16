#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

rename_falco_driver() {
  local -r cluster="${1}"
  local current_driver
  current_driver="$(yq_dig "${cluster}" '.falco.driver.kind')"

  if [[ "${current_driver}" == "modern-bpf" ]]; then
    log_info "Renaming falco driver from modern-bpf to modern_ebpf in ${cluster}-config..."
    yq_add "${cluster}" '.falco.driver.kind' '"modern_ebpf"'
  fi
}

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  rename_falco_driver sc
fi
if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
  rename_falco_driver wc
fi
rename_falco_driver common
