#!/usr/bin/env bash

# This script takes care of deploying Compliant Kubernetes Apps.
# It's not to be executed on its own but rather via 'ck8s apply'.

set -euo pipefail

declare here
here="$(dirname "$(readlink -f "$0")")"

# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
  log_error "error: invalid argument: \"${1:-}\""
  log_error "usage: ck8s apps <sc|wc> [sync] [--concurrency=#]"
  exit 1
}

update_ips_dryrun() {
  if ! "${here}/update-ips.bash" "$1" "dry-run"; then
    log_warning "---"
    log_warning "Found changed IPs for ${2/_/ } network policies, run 'ck8s update-ips $1 apply' to apply these changes"

    if ! "${CK8S_AUTO_APPROVE}"; then
      ask_abort
    fi
  fi
}

apps_apply() {
  local suppress

  local action="${3:-apply}"
  case "${action}" in
  apply) suppress="--suppress-diff" ;;
  sync) ;;
  *) usage "${action}" ;;
  esac

  local concurrency="${4:-}"
  case "${concurrency}" in
  --concurrency=*) ;;
  *) usage "${concurrency}" ;;
  esac

  log_info "---"
  log_info "Start Apps ${action} on ${2/_/ }"

  if (with_kubeconfig "${config["kube_config_$1"]}" helmfile -f "${here}/../helmfile.d/state.yaml" -e "$2" "${action}" "${concurrency}" "${suppress:-}"); then
    log_info "---"
    log_info "Successful Apps ${action} on ${2/_/ }!"
  else
    log_error "---"
    log_error "Failed Apps ${action} on ${2/_/ }!"
    exit 1
  fi
}

declare environment

case "${1:-}" in
sc)
  environment="service_cluster" ;;
wc)
  environment="workload_cluster" ;;
*)
  usage "${1:-}" ;;
esac

update_ips_dryrun "$1" "${environment}"
config_load "$1"
apps_apply "$1" "${environment}" "${@:2}"
