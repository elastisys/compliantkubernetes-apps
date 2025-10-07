#!/usr/bin/env bash

kubectl_do() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: kubectl_do <sc|wc> <args>..."
  fi

  local dry_run_flag=""
  if $CK8S_DRY_RUN_INSTALL; then
    local command="${2}"

    # List of common commands that generally DO NOT support --dry-run=server
    case "$command" in
    get | describe | logs | api-resources | api-versions | cluster-info | config | kustomize | proxy | version) ;;
    *)
      dry_run_flag="--dry-run=server"
      ;;
    esac
  fi

  if [ "${CONFIG["${1}-kubeconfig"]}" = "encrypted" ]; then
    kubeconfig_path="<(sops -d \"${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml\")"
  else
    kubeconfig_path="\"${CK8S_CONFIG_PATH}/.state/kube_config_${1}.yaml\""
  fi

  eval "kubectl --kubeconfig $kubeconfig_path $dry_run_flag \"\${@:2}\""
}

kubectl_delete() {
  if [[ "${#}" -lt 4 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: kubectl_delete <sc|wc> <resource> <namespace> <name>"
  fi

  kubectl_do "${1}" delete "${2}" --namespace "${3}" "${4}" --ignore-not-found true
}
