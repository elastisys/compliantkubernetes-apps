#!/usr/bin/env bash

if [[ -z "${ROOT:-}" ]]; then
  ROOT="$(git rev-parse --show-toplevel)"
fi
export ROOT

log_error() {
  echo "error: ${FUNCNAME[1]}: ${1:-}" >&2
}
log_fatal() {
  echo "fatal: ${FUNCNAME[1]}: ${1:-}" >&2
  exit 1
}

common_setup() {
  load "${ROOT}/tests/common/bats/assert/load.bash"
  load "${ROOT}/tests/common/bats/detik/lib/detik.bash"
  load "${ROOT}/tests/common/bats/detik/lib/linter.bash"
  load "${ROOT}/tests/common/bats/detik/lib/utils.bash"
  load "${ROOT}/tests/common/bats/support/load.bash"
}

# note: not intended for direct use
# usage: cypress_setup <path-to-cypress-spec>
cypress_setup() {
  if ! [[ -f "${1:-}" ]]; then
    log_fatal "invalid or missing file argument"
  fi

  CYPRESS_REPORT="$(mktemp)"

  pushd "${ROOT}/tests/common/cypress" || exit 1

  npx cypress run --project "$(dirname "$1")" --config-file "${ROOT}/tests/common/cypress/cypress.config.js" --spec "$1" --reporter json-stream --quiet > "${CYPRESS_REPORT}" || true

  popd || exit 1

  # Without json events we have some failure
  if ! grep -q '^\[.*\]$' < "${CYPRESS_REPORT}"; then
    cat "${CYPRESS_REPORT}" >&2
    exit 1
  fi

  # Filter json events
  grep '^\[.*\]$' < "${CYPRESS_REPORT}" > "${CYPRESS_REPORT}.tmp"
  mv "${CYPRESS_REPORT}.tmp" "${CYPRESS_REPORT}"

  # Check for any auto-generated error
  if [[ -n "$(jq -r 'select(.[1].title == "An uncaught error was detected outside of a test")' "${CYPRESS_REPORT}" 2>&1)" ]]; then
    echo "An uncaught error was detected outside of a test" >&2
    jq -r 'select(.[1].title == "An uncaught error was detected outside of a test") | .[1].stack' "${CYPRESS_REPORT}"
    exit 1
  fi

  export CYPRESS_REPORT
}

# note: not intended for direct use
# usage: cypress_test <group + test name>
cypress_test() {
  if ! [[ -f "${CYPRESS_REPORT:-}" ]]; then
    fail "invalid or missing cypress report"
  elif [[ -z "${1:-}" ]]; then
    fail "invalid or missing file argument"
  fi

  if [[ "$(jq -r "select(.[1].fullTitle == \"$1\") | .[0]" "${CYPRESS_REPORT}")" == "fail" ]]; then
    fail "$(jq -r "select(.[1].fullTitle == \"$1\") | .[1].stack" "${CYPRESS_REPORT}")"
  elif [[ "$(jq -r "select(.[1].fullTitle == \"$1\") | .[0]" "${CYPRESS_REPORT}")" == "pass" ]]; then
    assert true
  else
    skip "cypress skipped this test"
  fi
}

# note: not intended for direct use
# usage: cypress_teardown
cypress_teardown() {
  if [[ -f "${CYPRESS_REPORT:-}" ]]; then
    rm "${CYPRESS_REPORT}"
  fi
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

continue_on() {
  if [[ "${1:-}" =~ ^(sc|wc)$ ]]; then
    if [[ -n "${2:-}" ]]; then
      if [[ "$(yq_dig "$1" "$2" "false")" != "true" ]]; then
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
# usage: test_cronjob <name>
test_cronjob() {
  if [[ -n "${1:-}" ]]; then
    verify "there is 1 cronjob named '^$1$'"
  else
    fail "missing cronjob name argument"
  fi
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: test_daemonset <name>
test_daemonset() {
  if [[ -n "${1:-}" ]]; then
    verify "there is 1 daemonset named '^$1$'"
    verify "'status' is 'running' for pods named '$1-[[:alnum:]]\+[[:space:]]'"
  else
    fail "missing daemonset name argument"
  fi
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: test_deployment <name> <replicas>
test_deployment() {
  if [[ -n "${1:-}" ]]; then
    verify "there is 1 deployment named '^$1$'"
    verify "there are ${2:-1} pods named '$1-[[:alnum:]]\+-[[:alnum:]]\+$'"
    verify "'status' is 'running' for pods named '$1-[[:alnum:]]\+-[[:alnum:]]\+[[:space:]]'"
  else
    fail "missing deployment name argument"
  fi
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: test_statefulset <name> <replicas>
test_statefulset() {
  if [[ -n "${1:-}" ]]; then
    verify "there is 1 statefulset named '^$1$'"
    verify "there are ${2-1} pods named '$1-[[:digit:]]\+$'"
    verify "'status' is 'running' for pods named '$1-[[:digit:]]\+[[:space:]]'"
  else
    fail "missing statefulset name argument"
  fi
}
