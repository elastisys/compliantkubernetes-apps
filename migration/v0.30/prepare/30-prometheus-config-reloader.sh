#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

configs_names=("common" "sc" "wc")

for config in "${configs_names[@]}"; do
  if ! yq_null "$config" .prometheusOperator.configReloaderCpu; then
    log_info "- $config: move config reloader cpu"
    yq_move "$config" .prometheusOperator.configReloaderCpu .prometheusOperator.prometheusConfigReloader.resources.limits.cpu
  else
    log_info "- $config: no changes for configReloadCpu"
  fi

  if ! yq_null "$config" .prometheusOperator.configReloaderMemory; then
    log_info "- $config: move config reloader memory"
    yq_move "$config" .prometheusOperator.configReloaderMemory .prometheusOperator.prometheusConfigReloader.resources.limits.memory
  else
    log_info "- $config: no changes for configReloadMemory"
  fi
done
