#!/usr/bin/env bash

log_error() {
  echo "${FUNCNAME[1]} - ${1:-}" >&2
}
log_fatal() {
  echo "${FUNCNAME[1]} - ${1:-}" >&2
  exit 1
}

common_setup() {
  load "${PWD}/bats/assert/load.bash"
  load "${PWD}/bats/detik/lib/detik.bash"
  load "${PWD}/bats/detik/lib/linter.bash"
  load "${PWD}/bats/detik/lib/utils.bash"
  load "${PWD}/bats/support/load.bash"
}

# note: not intended for direct use
# usage: yq_dig <cluster> <config-key> <default>
yq_dig() {
  local value

  for config in "${CK8S_CONFIG_PATH}/$1-config.yaml" "${CK8S_CONFIG_PATH}/common-config.yaml" "${CK8S_CONFIG_PATH}/defaults/$1-config.yaml" "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"; do
    value=$(yq4 "$2" "${config}")

    if [[ "${value}" != "null" ]]; then
      echo "${value}"
      return
    fi
  done

  echo "$3"
}

# note: expects that the config key has an enabled field
# usage: skip_on_disabled <cluster> <config-key>
skip_on_disabled() {
  if [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    if [[ -n "${2:-}" ]]; then
      if [[ "$(yq_dig "$1" ".$2.enabled" "false")" != "true" ]]; then
        skip "$1/$2 - disabled"
      fi
    else
      fail "missing config key argument"
    fi
  elif [[ -n "${1:-}" ]]; then
    fail "invalid cluster argument"
  else
    fail "missing cluster argument"
  fi
}

# usage: get <cluster> <config-key>
get() {
  if [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    if [[ -n "${2:-}" ]]; then
      yq_dig "$1" ".$2" "0"
    else
      fail "missing config key argument"
    fi
  elif [[ -n "${1:-}" ]]; then
    fail "invalid cluster argument"
  else
    fail "missing cluster argument"
  fi
}

# sets the kubeconfig to use
# usage: with_kubeconfig <cluster>
with_kubeconfig() {
  if [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_$1.yaml"
    export DETIK_CLIENT_NAME="kubectl"
  elif [[ -n "${1:-}" ]]; then
    fail "invalid cluster argument"
  else
    fail "missing cluster argument"
  fi
}

# sets the namespace to use
# usage: with_namespace <namespace>
with_namespace() {
  if [[ -n "${1:-}" ]]; then
    export DETIK_CLIENT_NAMESPACE="$1"
  else
    fail "missing namespace argument"
  fi
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: check_deployment <name> <replicas>
check_deployment() {
  if [[ -n "${1:-}" ]]; then
    if [[ -n "${2:-}" ]]; then
      verify "there is 1 deployment named '^$1$'"
      verify "there are $2 pods named '$1-[[:alnum:]]\+-[[:alnum:]]\+$'"
      verify "'status' is 'running' for pods named '$1-[[:alnum:]]\+-[[:alnum:]]\+[[:space:]]'"
    else
      fail "missing deployment replicas argument"
    fi
  else
    fail "missing deployment name argument"
  fi
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: check_statefulset <name> <replicas>
check_statefulset() {
  if [[ -n "${1:-}" ]]; then
    if [[ -n "${2:-}" ]]; then
      verify "there is 1 statefulset named '^$1$'"
      verify "there are $2 pods named '$1-[[:digit:]]\+$'"
      verify "'status' is 'running' for pods named '$1-[[:digit:]]\+[[:space:]]'"
    else
      fail "missing statefulset replicas argument"
    fi
  else
    fail "missing statefulset name argument"
  fi
}
