#!/usr/bin/env bash

kubectl_do() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: kubectl_do <sc|wc> <args>..."
  fi

  if [ "${CONFIG["${1}-kubeconfig"]}" = "encrypted" ]; then
    kubectl --kubeconfig <(sops -d "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml") "${@:2}"
  else
    kubectl --kubeconfig "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml" "${@:2}"
  fi
}

kubectl_delete() {
  if [[ "${#}" -lt 4 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: kubectl_delete <sc|wc> <resource> <namespace> <name>"
  fi

  kubectl_do "${1}" delete "${2}" --namespace "${3}" "${4}" --ignore-not-found true
}
