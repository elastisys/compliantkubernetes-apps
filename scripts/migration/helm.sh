#!/usr/bin/env bash

helm_do() {
  if [[ ! "${1:-}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helm_do <sc|wc> <args>..."
  fi

  if [ "${CONFIG["${1}-kubeconfig"]}" = "encrypted" ]; then
    sops exec-file --no-fifo "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml" "KUBECONFIG={} helm ${*:2}"
  else
    helm --kubeconfig "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml" "${@:2}"
  fi
}

helm_installed() {
  if [[ "${#}" -lt 3 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: helm_installed <sc|wc> <namespace> <release>"
  fi

  helm_do "${1}" status -n "${2}" "${3}" > /dev/null 2>&1
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
