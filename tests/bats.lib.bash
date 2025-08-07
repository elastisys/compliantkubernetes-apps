#!/usr/bin/env bash

# Basic helpers for bats tests.

export BATS_LIB_PATH="/usr/local/lib/bats"

TESTS="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "${TESTS}")"

export PATH="${ROOT}/bin:${PATH}"

export CHARTS="${ROOT}/helmfile.d/charts"
export TESTS
export ROOT

export CK8S_TESTS_HARNESS="true"

log.fatal() {
  if [[ -e /dev/fd/3 ]]; then
    echo "error: ${1}" >&3
  else
    echo "error: ${1}" >&2
  fi
  exit 1
}

log.trace() {
  if [[ -e /dev/fd/3 ]]; then
    echo "# ${1}" >&3
  else
    echo "# ${1}" >&2
  fi
}

# setup a marker for serial tests to check progress
mark.setup() {
  TESTS_MARKER="$(mktemp)"
  export TESTS_MARKER
}

# teardown a marker for serial tests to check progress
mark.teardown() {
  [[ ! -f "${TESTS_MARKER:-}" ]] || rm "${TESTS_MARKER}"
}

# check a marker for serial tests
mark.check() {
  if [[ -n "${TESTS_MARKER:-}" ]]; then
    if [[ -f "${TESTS_MARKER:-}" ]] && [[ "$(cat "${TESTS_MARKER}")" == "pass" ]]; then
      rm "${TESTS_MARKER}"
    else
      skip "dependent tests failed"
    fi
  else
    fail "cannot check missing marker"
  fi
}

# punch a marker for serial tests
mark.punch() {
  if [[ -n "${TESTS_MARKER:-}" ]]; then
    echo "pass" >"${TESTS_MARKER}"
  else
    fail "cannot punch missing marker"
  fi
}

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
  bats_load_library "support/load.bash"
  bats_load_library "assert/load.bash"
}

load_detik() {
  bats_load_library "detik/lib/utils.bash"
  bats_load_library "detik/lib/detik.bash"
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

# sets the kubeconfig to use
# usage: with_static_wc_kubeconfig <dev|...?>
with_static_wc_kubeconfig() {
  local -r scope="${1:-dev}"

  BASE_KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"
  export KUBECONFIG="${CK8S_CONFIG_PATH}/.state/kube_config_wc_bats-${scope}.yaml"

  test -f "${KUBECONFIG}" || yq '.users[0].user.exec.args += ["'"--token-cache-dir=~/.kube/cache/oidc-login/test-static-${scope}"'", "--skip-open-browser"]' <"${BASE_KUBECONFIG}" >"${KUBECONFIG}"

  export DETIK_CLIENT_NAME="kubectl"

  kubectl auth whoami &
  local kc_pid=$!

  for _ in $(seq 1 40); do
    sleep .5
    if nc -z 127.0.0.1 8000; then
      # auth through cypress
      cypress_setup "${ROOT}/tests/end-to-end/kubernetes/authentication-${scope}.cy.js"
      break
    fi
    if ! kill -0 "${kc_pid}" >/dev/null 2>&1; then
      break
    fi
  done
  wait "${kc_pid}"
}

# deletes a kubeconfig used for tests
# usage: delete_static_wc_kubeconfig
delete_static_wc_kubeconfig() {
  local -r scope="${1:-dev}"
  rm -f "${CK8S_CONFIG_PATH}/.state/kube_config_wc_bats-${scope}.yaml"
}

clear_kubeconfig_cache() {
  if [[ -z "${1:-}" ]]; then
    fail "missing user argument (e.g. static-dev/static-admin)"
  fi

  rm -rf "${HOME}/.kube/cache/oidc-login/test-${1}"
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

# note: expects with_kubeconfig and with_namespace to be set
# usage: test_cronjob <name>
test_cronjob() {
  if [[ -z "${1:-}" ]]; then
    fail "missing cronjob name argument"
  fi

  verify "there is 1 cronjob named '^$1$'"
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: test_daemonset <name>
test_daemonset() {
  if [[ -z "${1:-}" ]]; then
    fail "missing daemonset name argument"
  fi

  verify "there is 1 daemonset named '^$1$'"
  verify "'status' is 'running' for pods named '$1-[[:alnum:]]+$'"
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: test_deployment <name> <replicas>
test_deployment() {
  if [[ -z "${1:-}" ]]; then
    fail "missing deployment name argument"
  fi

  verify "there is 1 deployment named '^$1$'"
  verify "there are ${2:-1} pods named '$1-[[:alnum:]]+-[[:alnum:]]+$'"
  verify "'status' is 'running' for pods named '$1-[[:alnum:]]+-[[:alnum:]]+'"
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: test_statefulset <name> <replicas>
test_statefulset() {
  if [[ -z "${1:-}" ]]; then
    fail "missing statefulset name argument"
  fi

  verify "there is 1 statefulset named '^$1$'"
  verify "there are ${2-1} pods named '$1-[[:digit:]]+$'"
  verify "'status' is 'running' for pods named '$1-[[:digit:]]+'"
}

# note: expects with_kubeconfig and with_namespace to be set
# usage: test_logs_contains <resource-type/name> <container> <regex>...
test_logs_contains() {
  run kubectl -n "${NAMESPACE}" logs "$1" grafana-sc-dashboard

  for arg in "${@:2}"; do
    assert_line --regexp "${arg}"
  done
}

auto_setup() {
  export CK8S_AUTO_APPROVE="true"

  local cluster="${1}"
  shift

  load_common "local-cluster.bash"

  log.trace "setup local cluster"
  local_cluster.setup dev test.dev-ck8s.com
  local_cluster.create "${cluster}" single-node-cache

  local_cluster.configure_selfsigned
  local_cluster.configure_node_local_dns

  log.trace "setup apply ${cluster} ${*}"
  ck8s ops helmfile "${cluster}" apply --include-transitive-needs --output simple "${@/#''/-l}"
}

auto_teardown() {
  local cluster="${1}"
  shift

  load_common "local-cluster.bash"

  log.trace "teardown local cluster"

  local_cluster.delete "${cluster}"
  local_cluster.teardown
}

# note: not intended for direct use
# usage: cypress_setup <path-to-cypress-spec>
cypress_setup() {
  if ! [[ -f "${1:-}" ]]; then
    log.fatal "invalid or missing file argument"
  fi

  declare -a cypress_args
  if [[ "${CK8S_HEADED_CYPRESS:-false}" == "true" ]]; then
    cypress_args=("--runner-ui" "--headed")
  else
    cypress_args=("--no-runner-ui")
  fi

  CYPRESS_REPORT="$(mktemp)"

  pushd "${ROOT}/tests" || exit 1

  log.trace "cypress run: $1"
  for seq in $(seq 3); do
    [[ "${seq}" == "1" ]] || log.trace "cypress run: try ${seq}/3"

    cypress run "${cypress_args[@]}" --spec "$1" --reporter json-stream --quiet >"${CYPRESS_REPORT}" || true

    # This happen seemingly at random
    if ! grep "Fatal JavaScript out of memory" "${CYPRESS_REPORT}" &>/dev/null; then
      break
    fi
  done

  popd || exit 1

  # Without json events we have some failure
  if ! grep -q '^\[.*\]$' <"${CYPRESS_REPORT}"; then
    cat "${CYPRESS_REPORT}" >&2
    exit 1
  fi

  # Filter json events
  grep '^\[.*\]$' <"${CYPRESS_REPORT}" >"${CYPRESS_REPORT}.tmp"
  mv "${CYPRESS_REPORT}.tmp" "${CYPRESS_REPORT}"

  # Check for any auto-generated error
  if [[ -n "$(jq -r 'select(.[1].title == "An uncaught error was detected outside of a test")' "${CYPRESS_REPORT}" 2>&1)" ]]; then
    echo "An uncaught error was detected outside of a test" >&2
    jq -r 'select(.[1].title == "An uncaught error was detected outside of a test") | .[1].stack' "${CYPRESS_REPORT}"
    exit 1
  fi

  # Check for "before-all" hook failure
  if [[ -n "$(jq -r 'select((.[0] == "fail") and (.[1].title | contains("\"before all\" hook for")))' "${CYPRESS_REPORT}")" ]]; then
    echo "One or more \"before all\" hooks failed" >&2
    jq -r 'select((.[0] == "fail") and (.[1].title | contains("\"before all\" hook for"))) | .[1].stack' "${CYPRESS_REPORT}"
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
