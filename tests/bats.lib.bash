#!/usr/bin/env bash

# Basic helpers for bats tests.

export BATS_LIB_PATH="/usr/local/lib/bats"

bats_load_library "support/load.bash"

TESTS="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "${TESTS}")"

export PATH="${ROOT}/bin:${PATH}"

export CHARTS="${ROOT}/helmfile.d/charts"
export TESTS
export ROOT

load_common() {
  local target

  if [[ -f "${TESTS}/common/bats/${1}" ]]; then
    target="${TESTS}/common/bats/${1}"
  else
    target="${TESTS}/common/lib/${1}"
  fi

  load "${target}"
}

load_assert() {
  bats_load_library "assert/load.bash"
}

load_detik() {
  bats_load_library "detik/utils.bash"
  bats_load_library "detik/detik.bash"
}

load_file() {
  bats_load_library "file/load.bash"
}

load_mock() {
  bats_load_library "mock/load.bash"
}

# sets the kubeconfig to use
# usage: with_kubeconfig <cluster>
with_kubeconfig() {
  if ! [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    fail "invalid or missing cluster argument"
  fi

  export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_$1.yaml"
  export DETIK_CLIENT_NAME="kubectl"
}

# sets the namespace to use
# usage: with_namespace <namespace>
with_namespace() {
  if [[ -z "${1:-}" ]]; then
    fail "missing namespace argument"
  fi

  export DETIK_CLIENT_NAMESPACE="$1"
  export NAMESPACE="$1"
}
