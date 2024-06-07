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
  - cache <create|delete>                                                    - manages local cache for local clusters
  - resolve <create|delete> <domain>                                         - manages local resolve for local clusters
  - config <name> <flavor> <domain> [ops-prefix]                             - configures a local cluster
  - create <name> <profile-name|profile-path> [--skip-calico] [--skip-minio] - creates a local cluster
  - delete <name>                                                            - deletes a local cluster
  - list clusters                                                            - lists available clusters
  - list profiles                                                            - lists available profiles
  "
}
log.continue() {
  if [[ "${CK8S_AUTO_APPROVE:-false}" != "true" ]]; then
    log.warn.no_newline "${1} [y/N]: "

    read -r reply
    if ! [[ "${reply}" =~ ^(y|Y|yes|Yes|YES)$ ]]; then
      log.fatal "aborted"
    fi
  fi
}

yq() {
  if command -v yq4 >/dev/null; then
    command yq4 "${@}"
  else
    command yq "${@}"
  fi
}

declare runtime
if command -v docker >/dev/null && docker --version >/dev/null 2>&1 && [[ ! "$(docker --version)" =~ Podman ]]; then
  runtime="docker"
elif command -v podman >/dev/null; then
  runtime="podman"
  export KIND_EXPERIMENTAL_PROVIDER="podman"
else
  log.fatal "no container runtime found" >&2
fi

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
    yq ".\"${cluster}\"" "${CK8S_CONFIG_PATH}/cluster-index.yaml" ;;
  "delete")
    yq -i "del(.\"${cluster}\")" "${CK8S_CONFIG_PATH}/cluster-index.yaml" ;;
  *)
    yq -i ".\"${cluster}\" = \"${state}\"" "${CK8S_CONFIG_PATH}/cluster-index.yaml" ;;
  esac
}

cluster.exist() {
  kind get clusters 2>/dev/null | grep -E "^${1}$" &>/dev/null
}

network.create() {
  if ! "${runtime}" network inspect "${1}" > /dev/null 2>&1; then
    log.info "- creating network ${1}"
    "${runtime}" network create "${1}"
  fi
}
container.create() {
  if ! "${runtime}" container inspect "${1}" > /dev/null 2>&1; then
    log.info "- creating container ${1}"
    "${runtime}" run --detach "${@:2}"
  else
    "${runtime}" start "${1}"
  fi
}
container.delete() {
  if "${runtime}" container inspect "${1}" > /dev/null 2>&1; then
    log.warn "- deleting container ${1}"
    "${runtime}" container stop "${1}"
    "${runtime}" container rm "${1}"
  fi
}
volume.create() {
  if ! "${runtime}" volume inspect "${1}" > /dev/null 2>&1; then
    log.info "- creating volume ${1}"
    "${runtime}" volume create "${1}"
  fi
}
volume.delete() {
  if "${runtime}" volume inspect "${1}" > /dev/null 2>&1; then
    log.warn "- deleting volume ${1}"
    "${runtime}" volume rm "${1}"
  fi
}

cache() {
  local action
  action="${1:-}"

  if [[ -z "${action}" ]]; then
    log.usage
  fi

  local -a registryfiles
  readarray -t registryfiles <<< "$(find "${HERE}/local-clusters/registries/" -type f)"

  for registryfile in "${registryfiles[@]}"; do
    local downstream name upstream

    downstream="$(yq -oy '.host | keys | .[0]' "${registryfile}")"

    name="$(sed -e 's#http://##' -e 's#:.*##' <<< "${downstream}")"

    upstream="$(yq -oy '.host | keys | .[1]' "${registryfile}")"

    log.info "---"
    log.info "${action}: ${registryfile}"

    case "${action}" in
    create)
      network.create kind
      volume.create "${name}"
      container.create "${name}" --env "REGISTRY_PROXY_REMOTEURL=${upstream}" --env REGISTRY_PROXY_TTL=168h --env REGISTRY_STORAGE_DELETE_ENABLED=true --env REGISTRY --mount "type=volume,src=${name},dst=/var/lib/registry" --name "${name}" --network kind docker.io/library/registry:2
      ;;
    delete)
      container.delete "${name}"
      volume.delete "${name}"
      ;;
    esac
  done
}

resolve() {
  local action domain
  action="${1:-}"
  domain="${2:-}"

  if [[ -z "${action}" ]]; then
    log.usage
  fi

  case "${action}" in
  create)
    if [[ -z "${domain}" ]]; then
      log.usage
    fi
    export domain

    network.create kind
    container.create local-resolve --env domain --mount "type=bind,src=${HERE}/local-clusters/resolves/Corefile,dst=/home/nonroot/Corefile" --name local-resolve --network kind --publish 127.0.64.43:53:53/tcp --publish 127.0.64.43:53:53/udp docker.io/coredns/coredns:1.11.1
    if command -v resolvectl >/dev/null 2>&1; then
      local link
      link="$(resolvectl default-route | sed -rn 's/.*\((.+)\): yes/\1/p')"
      log.continue "set local-resolve as current dns server on ${link}?"
      resolvectl dns "${link}" 127.0.64.43
    else
      log.warn "set local-resolve as the current dns server 127.0.64.43"
    fi
    ;;
  delete)
    container.delete local-resolve
    log.warn "reconnect your current network connection or restart systemd-resolved to restore previous dns servers!"
    ;;
  esac
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

  yq -Pi 'with(select(. == null); . = {}) | . *= (load(env(HERE) + "/local-clusters/configs/common-config.yaml") | (.. | select(tag == "!!str")) |= envsubst)' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq -Pi 'with(select(. == null); . = {}) | . *= (load(env(HERE) + "/local-clusters/configs/sc-config.yaml") | (.. | select(tag == "!!str")) |= envsubst)' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq -Pi 'with(select(. == null); . = {}) | . *= (load(env(HERE) + "/local-clusters/configs/wc-config.yaml") | (.. | select(tag == "!!str")) |= envsubst)' "${CK8S_CONFIG_PATH}/wc-config.yaml"

  if ! [[ -f "${CK8S_CONFIG_PATH}/defaults/common-config.yaml" ]]; then
    mkdir -p "${CK8S_CONFIG_PATH}/defaults"
    touch "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
    yq -Pi '. = {
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
    kind create cluster --name "${cluster}" --config /dev/stdin <<< "$(envsubst < "${config}")"
    index.state "${cluster}" "configuring"
  fi

  mkdir -p "${CK8S_CONFIG_PATH}/.state"
  kind get kubeconfig --name "${cluster}" > "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
  kind get kubeconfig --name "${cluster}" > "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"

  chmod 600 "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
  chmod 600 "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"

  export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"

  if [[ -n "${KIND_EXPERIMENTAL_PROVIDER:-}" ]]; then
    # Ensure DNS resolution works when running in podman
    kubectl get configmap -n kube-system coredns -oyaml | sed '/forward/a \           prefer_udp' | kubectl apply -f -
  fi

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
  cache)
    case "${subcommand}" in
    create|delete)
      cache "${subcommand}" ;;
    *)
      log.usage ;;
    esac
    ;;
  resolve)
    case "${subcommand}" in
    create|delete)
      resolve "${subcommand}" "${@:3}" ;;
    *)
      log.usage ;;
    esac
    ;;
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
