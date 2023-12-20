#!/usr/bin/env bash

# Contributor helpers to run local clusters

set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "${HERE}")"

export HERE
export ROOT

log.info.no_newline() {
  echo -en "[\e[34mck8s\e[0m] ${*}" 1>&2
}
log.info() {
  log.info.no_newline "${*}\n"
}
log.warn.no_newline() {
  echo -e -n "[\e[33mck8s\e[0m] ${*}" 1>&2
}
log.warn() {
  log.warn.no_newline "${*}\n"
}
log.error.no_newline() {
  echo -e -n "[\e[31mck8s\e[0m] ${*}" 1>&2
}
log.error() {
  log.error.no_newline "${*}\n"
}
log.fatal() {
  log.error "${*}"
  exit 1
}
log.usage() {
  log.fatal "$0 usage:
  - config <name> <flavor> <domain> [ops-prefix]                             - configures a local cluster
  - create <name> <profile-name|profile-path> [--skip-calico] [--skip-minio] - creates a local cluster
  - delete <name>                                                            - deletes a local cluster
  - list clusters                                                            - lists available clusters
  - list profiles                                                            - lists available profiles
  "
}
log.continue() {
  log.warn.no_newline "${1} [y/N]: "

  read -r reply
  if ! [[ "${reply}" =~ ^(y|Y|yes|Yes|YES)$ ]]; then
    log.fatal "aborted"
  fi
}

list.clusters() {
  kind get clusters 2>/dev/null
}
list.profiles() {
  echo "${HERE}/local-clusters/profiles/"*.yaml | tr ' ' '\n' | sed -e "s#${HERE}/local-clusters/profiles/##" -e 's#.yaml$##'
}

index.state() {
  local cluster state
  cluster="${1:-}"
  state="${2:-}"

  if [[ -z "${CK8S_CONFIG_PATH:-}" ]]; then
    log.fatal "CK8S_CONFIG_PATH is unset"
  fi

  if ! [[ -d "${CK8S_CONFIG_PATH}" ]]; then
    mkdir -p "${CK8S_CONFIG_PATH}"
  fi

  if ! [[ -f "${CK8S_CONFIG_PATH}/cluster-index.yaml" ]]; then
    touch "${CK8S_CONFIG_PATH}/cluster-index.yaml"
  fi

  case "${state}" in
  "")
    yq4 ".\"${cluster}\"" "${CK8S_CONFIG_PATH}/cluster-index.yaml" ;;
  "delete")
    yq4 -i "del(.\"${cluster}\")" "${CK8S_CONFIG_PATH}/cluster-index.yaml" ;;
  *)
    yq4 -i ".\"${cluster}\" = \"${state}\"" "${CK8S_CONFIG_PATH}/cluster-index.yaml" ;;
  esac
}

cluster.exist() {
  kind get clusters 2>/dev/null | grep -E "^${1}$" &>/dev/null
}

config() {
  local name flavor domain ops_prefix
  name="${1:-}"
  flavor="${2:-}"
  domain="${3:-}"
  ops_prefix="${4:-"ops"}"

  export name
  export domain
  export flavor
  export ops_prefix

  if [[ -z "${name}" ]] || [[ -z "${flavor}" ]] || [[ -z "${domain}" ]]; then
    log.usage
  fi

  if [[ -z "${CK8S_CONFIG_PATH:-}" ]]; then
    log.fatal "CK8S_CONFIG_PATH is unset"
  fi

  if ! [[ -d "${CK8S_CONFIG_PATH}" ]]; then
    mkdir -p "${CK8S_CONFIG_PATH}"
  fi

  if ! [[ -f "${CK8S_CONFIG_PATH}/common-config.yaml" ]]; then
    touch "${CK8S_CONFIG_PATH}/common-config.yaml"
  fi

  if ! [[ -f "${CK8S_CONFIG_PATH}/sc-config.yaml" ]]; then
    touch "${CK8S_CONFIG_PATH}/sc-config.yaml"
  fi

  if ! [[ -f "${CK8S_CONFIG_PATH}/wc-config.yaml" ]]; then
    touch "${CK8S_CONFIG_PATH}/wc-config.yaml"
  fi

  yq4 -Pi 'with(select(. == null); . = {}) | . *= (load(env(HERE) + "/local-clusters/configs/common-config.yaml") | (.. | select(tag == "!!str")) |= envsubst)' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq4 -Pi 'with(select(. == null); . = {}) | . *= (load(env(HERE) + "/local-clusters/configs/sc-config.yaml") | (.. | select(tag == "!!str")) |= envsubst)' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -Pi 'with(select(. == null); . = {}) | . *= (load(env(HERE) + "/local-clusters/configs/wc-config.yaml") | (.. | select(tag == "!!str")) |= envsubst)' "${CK8S_CONFIG_PATH}/wc-config.yaml"

  if ! [[ -f "${CK8S_CONFIG_PATH}/defaults/common-config.yaml" ]]; then
    mkdir -p "${CK8S_CONFIG_PATH}/defaults"
    touch "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
    yq4 -Pi '. = {
      "global": {
          "ck8sCloudProvider": "none",
          "ck8sEnvironmentName": (env(name)),
          "ck8sFlavor": (env(flavor))
      }
    }' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  fi

  "${ROOT}/bin/ck8s" init both
}

create() {
  local cluster config
  cluster="${1:-}"
  config="${2:-}"

  if [[ -z "${cluster}" ]]; then
    log.usage
  fi

  if [[ -f "${config}" ]]; then
    config="$(readlink -f "${config}")"
  elif [[ -f "${HERE}/local-clusters/profiles/${config}.yaml" ]]; then
    config="${HERE}/local-clusters/profiles/${config}.yaml"
  else
    log.fatal "config or profile \"${config}\" is not valid"
  fi

  if [[ "$(index.state "${cluster}")" == "ready" ]]; then
    log.info "cluster ${cluster} is in ready state, aborting"
    exit
  fi

  if cluster.exist "${cluster}"; then
    if [[ "$(index.state "${cluster}")" == "configuring" ]]; then
      log.info "cluster ${cluster} is in configuring state, continuing"
    elif [[ "$(index.state "${cluster}")" == "creating" ]]; then
      log.info "cluster ${cluster} is in creating state, continuing"
      index.state "${cluster}" "configuring"
    else
      log.continue "cluster ${cluster} already exists\n  - do you want to adopt it?"
      index.state "${cluster}" "configuring"
    fi
  else
    index.state "${cluster}" "creating"
  fi

  if [[ "$(index.state "${cluster}")" == "creating" ]]; then
    log.info "kind create cluster \"${cluster}\" using \"${config}\""
    kind create cluster --name "${cluster}" --config "${config}"
    index.state "${cluster}" "configuring"
  fi

  mkdir -p "${CK8S_CONFIG_PATH}/.state"
  kind get kubeconfig --name "${cluster}" > "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
  kind get kubeconfig --name "${cluster}" > "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"

  chmod 600 "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
  chmod 600 "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"

  export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"

  kubectl label namespace local-path-storage owner=operator

  # install calico
  if ! [[ "${*}" =~ --skip-calico ]]; then
    log.info "installing calico"

    kubectl get namespace calico-apiserver &>/dev/null || kubectl create namespace calico-apiserver
    kubectl get namespace calico-system &>/dev/null || kubectl create namespace calico-system
    kubectl get namespace tigera-operator &>/dev/null || kubectl create namespace tigera-operator

    kubectl label namespaces calico-apiserver calico-system tigera-operator owner=operator

    helmfile -e local_cluster -f "${ROOT}/helmfile.d" -lapp=tigera apply --output simple
  fi

  # install s3
  if ! [[ "${*}" =~ --skip-minio ]]; then
    log.info "installing minio"

    kubectl get namespace minio-system &>/dev/null || kubectl create namespace minio-system

    kubectl label namespace minio-system owner=operator

    helmfile -e local_cluster -f "${ROOT}/helmfile.d" -lapp=minio apply --output simple
  fi

  index.state "${cluster}" "ready"
  log.info "cluster ${cluster} is ready"
}

delete() {
  local cluster
  cluster="${1:-}"

  if [[ -z "${cluster}" ]]; then
    log.usage
  fi

  if cluster.exist "${cluster}"; then
    if [[ "$(index.state "${cluster}")" == "null" ]]; then
      log.continue "cluster ${cluster} is not managed by this index\n  - do you want to delete it?"
    fi
    log.continue "cluster ${cluster} is about to be deleted\n  - do you want to delete it?"
    log.warn "kind delete cluster \"${cluster}\""
    kind delete cluster --name "${cluster}"
    index.state "${cluster}" "delete"
    log.warn "cluster \"${cluster}\" is deleted"
  else
    if [[ "$(index.state "${cluster}")" != "null" ]]; then
      log.warn "cluster ${cluster} is already deleted"
      index.state "${cluster}" "delete"
    else
      log.warn "cluster ${cluster} is not defined"
    fi
  fi
}

main() {
  local command subcommand
  command="${1:-}"
  subcommand="${2:-}"

  case "${command}" in
  config)
    config "${@:2}" ;;
  create)
    create "${@:2}" ;;
  delete)
    delete "${@:2}" ;;
  list)
    case "${subcommand}" in
      clusters|cluster)
        list.clusters ;;
      profiles|profile)
        list.profiles ;;
      *)
        log.usage ;;
    esac
    ;;
  *)
    log.usage ;;
  esac
}

main "${@}"
