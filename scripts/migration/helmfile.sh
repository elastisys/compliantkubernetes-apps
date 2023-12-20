#!/usr/bin/env bash

helmfile_do() {
  local environment

  case "${1:-}" in
  sc)
    environment="service_cluster"
    ;;
  wc)
    environment="workload_cluster"
    ;;
  *)
    log_fatal "usage: helmfile_do <sc|wc> <args>..."
    ;;
  esac

  if [ "${CONFIG["${1}-kubeconfig"]}" = "encrypted" ]; then
    sops exec-file --no-fifo "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml" "KUBECONFIG={} helmfile -e ${environment} -f ${ROOT}/helmfile.d/ ${*:2}"
  else
    KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml" helmfile -e "${environment}" -f "${ROOT}/helmfile.d/" "${@:2}"
  fi
}

helmfile_list() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helmfile_list <sc|wc> <selectors>..."
  fi

  prefix="${1}"
  shift

  helmfile_do "${prefix}" list "${@/#/-l}" --output json --quiet
}

helmfile_apply() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helmfile_apply <sc|wc> <selectors>..."
  fi

  prefix="${1}"
  shift

  helmfile_do "${prefix}" apply "${@/#/-l}" --output simple --skip-diff-on-install --quiet
}

helmfile_change() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helmfile_change <sc|wc> <selectors>..."
  fi

  prefix="${1}"
  shift

  helmfile_do "${prefix}" diff "${@/#/-l}" --detailed-exitcode --output simple --quiet
}

# usage: helmfile_destroy <sc|wc> <selectors...>
helmfile_destroy() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helmfile_destroy <sc|wc> <selectors>..."
  fi

  prefix="${1}"
  shift

  helmfile_do "${prefix}" destroy "${@/#/-l}" --quiet
}

# for each release matching the selectors dispatch a function on each individual release
helmfile_change_dispatch() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${2}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helmfile_change_dispatch <function> <sc|wc> <selectors>..."
  fi

  local list
  if ! list="$(helmfile_list "${2}" "${@:3}" 2> /dev/null)"; then
      log_warn "warning: ${2} ${*:3} had no matching releases"
      return
  fi
  list="$(yq4 -P '[.[] | select(.enabled and .installed)]' <<< "${list}")"

  local length
  length="$(yq4 -P 'length' <<< "${list}")"
  for index in $(seq 0 $((length - 1))); do
    namespace="$(yq4 -P ".[${index}].namespace" <<< "${list}")"
    name="$(yq4 -P ".[${index}].name" <<< "${list}")"

    if helmfile_change "${2}" "namespace=${namespace},name=${name}" > /dev/null 2>&1; then
      log_info "  - skipping ${2} ${namespace}/${name} no change"
      continue
    fi

    "${1}" "${2}" "${namespace}" "${name}"
  done
}

# will uninstall and install the matching releases as required
helmfile_replace() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helmfile_replace <sc|wc> <selectors>..."
  fi

  log_info "replacing ${1} ${*:2}"

  # shellcheck disable=SC2317

  # prefix namespace name
  internal_helmfile_replace() {
    log_info "  - replacing ${1} ${2}/${3}"

    if ! helmfile_destroy "${1}" "namespace=${2},name=${3}"; then
      log_error "error: failed to destroy ${1} ${2}/${3}"
      return 1
    fi

    if ! helmfile_apply "${1}" "namespace=${2},name=${3}"; then
      log_error "error: failed to upgrade ${1} ${2}/${3}"
      return 1
    fi
  }

  helmfile_change_dispatch internal_helmfile_replace "${1}" "${@:2}"
}

# will upgrade the matching releases as required
# will rollback on failure if CK8S_ROLLBACK is not false
helmfile_upgrade() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helmfile_upgrade <sc|wc> <selectors>..."
  fi

  log_info "upgrading ${1} ${*:2}"

  # shellcheck disable=SC2317

  # prefix namespace name
  internal_helmfile_upgrade() {
    log_info "  - upgrading ${1} ${2}/${3}"

    if ! helmfile_apply "${1}" "namespace=${2},name=${3}"; then
      log_error "error: failed to upgrade ${1} ${2}/${3}"

      if [ "${CK8S_ROLLBACK:-}" != "false" ]; then
        log_warn "  - rolling back ${1} ${2}/${3}"

        if helm_do "${1}" rollback --namespace "${2}" "${3}"; then
          return 2
        fi

        log_error "error: failed to rollback ${1} ${2}/${3}"
      fi

      return 1
    fi
  }

  helmfile_change_dispatch internal_helmfile_upgrade "${1}" "${@:2}"
}
