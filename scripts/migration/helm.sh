#!/usr/bin/env bash

helm_do() {
  if [[ ! "${1:-}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helm_do <sc|wc> <args>..."
  fi

  local -a args=()
  local -a command_args=("${@:2}")
  local command="${2}"

  if [[ "${command}" =~ ^- ]]; then
    log_fatal "Second argument must be a helm operation, not an option"
  fi

  if [[ "${CK8S_DRY_RUN_INSTALL:-"false"}" == "true" ]]; then
    # List of common Helm subcommands that generally DO NOT support --dry-run
    case "${command}" in
    get | list | ls | history | diff | repo | search | show | status | test | version) ;;
    *)
      command_args=("${command}" "--dry-run" "${@:3}")
      ;;
    esac
  fi

  args+=("${command_args[@]}")

  if [ "${CONFIG["${1}-kubeconfig"]}" = "encrypted" ]; then
    sops exec-file --no-fifo "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml" "KUBECONFIG={} helm ${args[*]}"
  else
    helm --kubeconfig "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml" "${args[@]}"
  fi
}

helm_chart_name() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helm_chart_name <sc|wc> <namespace> <release>"
  fi

  helm_do "${1}" list -n "${2}" -oyaml 2>/dev/null | yq ".[] | select(.name == \"${3}\") | .chart | sub(\"-\d+\.\d+\.\d+$\", \"\")"
}

helm_chart_version() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helm_chart_version <sc|wc> <namespace> <release>"
  fi

  helm_do "${1}" list -n "${2}" -oyaml 2>/dev/null | yq ".[] | select(.name == \"${3}\") | .chart | match(\"\d+\.\d+\.\d+\") | .string"
}

helm_installed() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helm_installed <sc|wc> <namespace> <release>"
  fi

  helm_do "${1}" status -n "${2}" "${3}" >/dev/null 2>&1
}

helm_rollback() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helm_rollback <sc|wc> <namespace> <release>"
  fi

  if helm_installed "${@}"; then
    log_info "  - rolling back ${1} ${2}/${3}"
    helm_do "${1}" rollback -n "${2}" "${3}"
  fi
}

helm_uninstall() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helm_uninstall <sc|wc> <namespace> <release>"
  fi

  if helm_installed "${@}"; then
    log_info "  - uninstalling ${1} ${2}/${3}"
    helm_do "${1}" uninstall -n "${2}" "${3}"
  fi
}
