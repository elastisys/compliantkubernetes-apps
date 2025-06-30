#!/usr/bin/env bash

# This script takes care of deploying Welkin Apps.
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

check_upgrade() {
  if get_upgrade_status "${1}" &>/dev/null; then
    log_fatal "Upgrade ongoing, try again when it has completed or use 'ck8s upgrade unlock'"
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

  if (with_kubeconfig "${config["kube_config_$1"]}" helmfile -f "${here}/../helmfile.d/" -e "$2" "${action}" "${concurrency}" "${suppress:-}"); then
    log_info "---"
    local current_version
    current_version="$(get_apps_version "${1}" 2>/dev/null || true)"
    if [ -z "${current_version}" ]; then
      current_version="$(get_repo_version)"
      if [[ "${current_version}" == v* ]]; then
        set_apps_version "${1}" "${current_version%.*}"
      fi
    fi
    log_info "Current version is ${current_version}"
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
  environment="service_cluster"
  ;;
wc)
  environment="workload_cluster"
  ;;
*)
  usage "${1:-}"
  ;;
esac

check_node_label "$1" elastisys.io/node-group
update_ips_dryrun "$1" "${environment}"
check_upgrade "$1"
config_load "$1"
[[ -z "${CK8S_CI_SKIP_APPLY:-}" ]] || exit 0 # Improve mockability in the future
apps_apply "$1" "${environment}" "${@:2}"
