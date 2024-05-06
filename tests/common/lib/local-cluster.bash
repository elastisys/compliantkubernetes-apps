#!/usr/bin/env bash

declare lib
declare scripts

declares() {
  lib="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

  scripts="$(dirname "$(dirname "$(dirname "${lib}")")")/scripts"
}

declares

load "${lib}/env.bash"
load "${lib}/gpg.bash"

# Usage: local_cluster.setup <config-flavour> <domain>
local_cluster.setup() {
  declares
  env.setup
  gpg.setup

  mkdir -p "${CK8S_CONFIG_PATH}/.state"
  export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config.yaml"

  "${scripts}/local-cluster.sh" config apps-tests "${@}"
}

# Usage: local_cluster.create <local-cluster-profile>
local_cluster.create() {
  declares
  "${scripts}/local-cluster.sh" create apps-tests "${@}"
  cp "${CK8S_CONFIG_PATH}/.state/kube_config.yaml" "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
  cp "${CK8S_CONFIG_PATH}/.state/kube_config.yaml" "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"
}

local_cluster.delete() {
  declares
  CK8S_AUTO_APPROVE=true "${scripts}/local-cluster.sh" delete apps-tests
}

local_cluster.teardown() {
  declares
  gpg.teardown
  env.teardown
}
