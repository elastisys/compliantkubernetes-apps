#!/usr/bin/env bash

: "${CK8S_CLUSTER:?Missing CK8S_CLUSTER}"

here="$(readlink -f "$(dirname "${0}")")"

ROOT="$(readlink -f "${here}/../")"
# Allow overriding from test suite
MIGRATION_ROOT="${MIGRATION_ROOT:-"${ROOT}/migration"}"

CK8S_STACK="$(basename "$0")"
export CK8S_STACK

# shellcheck source=bin/common.bash
source "${here}/common.bash"

# shellcheck source=scripts/migration/lib.sh
CK8S_ROOT_SCRIPT="true" source "${ROOT}/scripts/migration/lib.sh"

snippets_list() {
  if [[ ! "${1}" =~ ^(prepare|apply)$ ]]; then
    log_fatal "usage: snippets_list <prepare|apply>"
  fi

  echo "${MIGRATION_ROOT}/${CK8S_TARGET_VERSION}/${1}/"* | sort
}

snippets_check() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(prepare|apply)$ ]]; then
    log_fatal "usage: snippets_check <prepare|apply> <snippets...>"
  fi

  local action="${1}"
  local snippets="${*:2}"

  local pass="true"
  for snippet in ${snippets}; do
    if [[ "$(basename "${snippet}")" == "00-template.sh" ]]; then
      continue
    fi

    if [[ ! -x "${snippet}" ]]; then
      log_error "error: ${action} snippet \"${snippet}\" is invalid (not executable)"
      pass="false"
    fi
  done
  if [ "${pass}" == "false" ]; then
    exit 1
  fi

  log_info "${action} snippets checked\n---"
}

prepare() {
  local snippets
  snippets="$(snippets_list prepare)"

  snippets_check prepare "${snippets}"

  for snippet in ${snippets}; do
    if [[ "$(basename "${snippet}")" == "00-template.sh" ]]; then
      continue
    fi
    log_info "prepare snippet \"${snippet##"${MIGRATION_ROOT}/"}\":"
    if "${snippet}"; then
      log_info "prepare snippet success\n---"
    else
      log_fatal "prepare snippet failure"
    fi
  done

  # Record, in the cluster, that an upgrade has been prepared so that nobody else starts the apply.
  if [[ "${CK8S_CLUSTER:-}" =~ ^(sc|both)$ ]]; then
    record_upgrade_prepare_done sc
  fi
  if [[ "${CK8S_CLUSTER:-}" =~ ^(wc|both)$ ]]; then
    record_upgrade_prepare_done wc
  fi

  config_validate secrets
  if [[ "${CK8S_CLUSTER:-}" =~ ^(sc|both)$ ]]; then
    config_validate sc
  fi
  if [[ "${CK8S_CLUSTER:-}" =~ ^(wc|both)$ ]]; then
    config_validate wc
  fi
}

apply() {
  config_validate secrets
  if [[ "${CK8S_CLUSTER:-}" =~ ^(sc|both)$ ]]; then
    config_validate sc
  fi
  if [[ "${CK8S_CLUSTER:-}" =~ ^(wc|both)$ ]]; then
    config_validate wc
  fi

  # TODO: Template validation
  # for prefix in sc wc; do
  #   template_validate "${prefix}"
  # done

  local snippets
  snippets="$(snippets_list apply)"

  snippets_check apply "${snippets}"

  for snippet in ${snippets}; do
    if [[ "$(basename "${snippet}")" == "00-template.sh" ]]; then
      continue
    fi

    log_info "apply snippet \"${snippet##"${MIGRATION_ROOT}/"}\":"
    if "${snippet}" execute; then
      log_info "apply snippet success\n---"
      if [[ "${CK8S_CLUSTER:-}" == "both" ]]; then
        record_upgrade_apply_step "sc" "${snippet}"
        record_upgrade_apply_step "wc" "${snippet}"
      else
        record_upgrade_apply_step "${CK8S_CLUSTER}" "${snippet}"
      fi
    else
      local return="${?}"
      log_error "apply snippet execute failure"

      if [[ "${return}" == 2 ]]; then
        log_warn "apply snippet execute rollback"
      fi

      if "${snippet}" rollback; then
        log_warn "apply snippet rollback success"
        exit $((return + 2)) # 3 on rollback failure/success 4 on rollback success/success
      else
        log_error "apply snippet rollback failure"
        exit $((return)) # 1 on rollback failure/failure 2 on rollback success/failure
      fi
    fi
  done

  if [[ "${CK8S_CLUSTER:-}" =~ ^(sc|both)$ ]]; then
    record_upgrade_done sc
  fi
  if [[ "${CK8S_CLUSTER:-}" =~ ^(wc|both)$ ]]; then
    record_upgrade_done wc
  fi
}

usage() {
  if [[ -n "${1:-}" ]]; then
    log_error "invalid command \"${1}\"\n"
  else
    log_error "missing command\n"
  fi

  printf "commands:\n" 1>&2
  printf "\tprepare <version> \t- run all prepare steps upgrading the configuration\n" 1>&2
  printf "\tapply <version>   \t- run all apply steps upgrading the environment\n" 1>&2

  exit 1
}

main() {
  if [[ "${1}" == "unlock" ]]; then
    unlock
    return
  fi

  local version="${1}"
  local action="${2}"

  local pass="true"
  for dir in "" "prepare" "apply"; do
    if [[ ! -d "${MIGRATION_ROOT}/${version}/${dir}" ]]; then
      log_error "error: migration/${version}/${dir} is not a directory, did you specify the correct version?"
      pass="false"
    fi
  done
  if [[ "${pass}" = "false" ]]; then
    exit 1
  fi

  export CK8S_TARGET_VERSION="${version}"
  export CK8S_STACK="${version}/${action}"

  check_config

  if [[ "${CK8S_CLUSTER:-}" =~ ^(sc|both)$ ]]; then
    config_load "sc"
    check_version "sc" "${action}"
    check_node_label "sc" elastisys.io/node-group
  fi
  if [[ "${CK8S_CLUSTER:-}" =~ ^(wc|both)$ ]]; then
    config_load "wc"
    check_version "wc" "${action}"
    check_node_label "wc" elastisys.io/node-group
  fi

  "${action}"

  log_info "${action} complete"
}

unlock() {
  check_config
  if [[ "${CK8S_CLUSTER:-}" =~ ^(sc|both)$ ]]; then
    config_load "sc"
    unlock_upgrade "sc"
  fi
  if [[ "${CK8S_CLUSTER:-}" =~ ^(wc|both)$ ]]; then
    config_load "wc"
    unlock_upgrade "wc"
  fi
  log_info "Cluster upgrade unlocked. You can now retry the upgrade"
}

main "${@}"
