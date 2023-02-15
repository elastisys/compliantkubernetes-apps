#!/usr/bin/env bash

here="$(readlink -f "$(dirname "${0}")")"

ROOT="$(readlink -f "${here}/../")"

CK8S_STACK="$(basename "$0")"
export CK8S_STACK

# shellcheck source=scripts/migration/lib.sh
CK8S_ROOT_SCRIPT="true" source "${ROOT}/scripts/migration/lib.sh"

snippets_list() {
  if [[ ! "${1}" =~ ^(prepare|apply)$ ]]; then
    log_fatal "usage: snippets_list <prepare|apply>"
  fi

  echo "${ROOT}/migration/${CK8S_TARGET_VERSION}/${1}/"* | sort
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

    log_info "prepare snippet \"${snippet##"${ROOT}/migration/"}\":"
    if "${snippet}"; then
      log_info "prepare snippet success\n---"
    else
      log_fatal "prepare snippet failure"
    fi
  done

  for prefix in secrets sc wc; do
    config_validate "${prefix}"
  done
}

apply() {
  for prefix in secrets sc wc; do
    config_validate "${prefix}"
  done

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

    log_info "apply snippet \"${snippet##"${ROOT}/migration/"}\":"
    if "${snippet}" execute; then
      log_info "apply snippet success\n---"
    else
      local return="${?}"
      log_error "apply snippet execute failure"

      if [[ "${return}" == 2 ]]; then
        log_warn "apply snippet execute rollback"
      fi

      if "${snippet}" rollback; then
        log_warn "apply snippet rollback success"
        exit $(( return + 2 )) # 3 on rollback failure/success 4 on rollback success/success
      else
        log_error "apply snippet rollback failure"
        exit $(( return )) # 1 on rollback failure/failure 2 on rollback success/failure
      fi
    fi
  done
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
  if [[ "${#}" -lt 2 ]] || [[ ! "${2}" =~ ^(prepare|apply)$ ]]; then
    usage "${2:-}"
  fi

  local version="${1}"
  local action="${2}"

  local pass="true"
  for dir in "" "prepare" "apply"; do
    if [[ ! -d "${ROOT}/migration/${version}/${dir}" ]]; then
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

  for prefix in sc wc; do
    config_load "${prefix}"
    check_version "${prefix}" "${action}"
  done

  "${action}" "${version}"

  log_info "${action} complete"
}

main "${@}"
