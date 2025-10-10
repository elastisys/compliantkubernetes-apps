#!/usr/bin/env bash

kubectl_do() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: kubectl_do <sc|wc> <args>..."
  fi

  local -a args=()
  if [[ "${CK8S_DRY_RUN_INSTALL}" == "true" ]]; then
    local command="${2}"
    # List of common commands that generally DO NOT support --dry-run=server
    case "${command}" in
    get | describe | logs | api-resources | api-versions | cluster-info | config | kustomize | proxy | version) ;;
    *)
      args+=("--dry-run=server")
      ;;
    esac
  fi

  args+=("${@:2}")
  if [ "${CONFIG["${1}-kubeconfig"]}" = "encrypted" ]; then
    kubectl --kubeconfig <(sops -d "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml") "${args[@]}"
  else
    kubectl --kubeconfig "${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml" "${args[@]}"
  fi
}

kubectl_delete() {
  if [[ "${#}" -lt 4 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: kubectl_delete <sc|wc> <resource> <namespace> <name>"
  fi

  kubectl_do "${1}" delete "${2}" --namespace "${3}" "${4}" --ignore-not-found true
}
