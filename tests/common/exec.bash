#!/usr/bin/env bash

# Executive commands for the test harness

set -euo pipefail

declare roots tests
tests="$(dirname "$(dirname "$(readlink -f "$0")")")"
roots="$(dirname "${tests}")"

declare runtime
if command -v docker >/dev/null && docker version &>/dev/null && [[ ! "$(docker version)" =~ Podman ]]; then
  runtime="docker"
elif command -v podman >/dev/null; then
  runtime="podman"
else
  echo "no container runtime found" >&2
  exit 1
fi

check_image() {
  if ! "${runtime}" image inspect "${1:-}" &>/dev/null; then
    echo "error: image ${1:-} is not built" >&2
    return 1
  fi
}
check_container() {
  if ! "${runtime}" container inspect "${1:-}" &>/dev/null; then
    echo "error: container ${1:-} is not running" >&2
    return 1
  fi
  if [[ ! "$("${runtime}" container inspect "${1:-}" --format '{{ .State.Running }}')" == "true" ]]; then
    echo "error: container ${1:-} is not running" >&2
    return 1
  fi
}
check_resolve() {
  if ! resolvectl query dot.test.dev-ck8s.com &>/dev/null; then
    echo "error: dns does not resolve with local-resolve" >&2
    return 1
  fi
  if [[ "$(resolvectl query dot.test.dev-ck8s.com | awk '/dot.test.dev-ck8s.com:/{ print $2 }')" != "127.0.64.43" ]]; then
    echo "error: dns does not resolve to local-cluster" >&2
    return 1
  fi
}

# Load override to source bats lib.
load() {
  if [[ -z "${1:-}" ]]; then
    echo "error: missing file argument" >&2
    exit 1
  fi

  if [[ "${1:-}" =~ ^/ ]]; then
    # shellcheck disable=SC1090
    source "${1}"
  else
    # shellcheck disable=SC1090
    source "${suite}/${1}"
  fi
}

preflight.unit() {
  local failure="false"

  if ! check_image compliantkubernetes-apps-tests:unit; then failure="true"; fi

  if [[ "${failure}" == "true" ]]; then
    echo "error: preflight checks failure for unit tests" >&2
    exit 1
  fi
}
preflight.regression() {
  local failure="false"

  if ! check_image compliantkubernetes-apps-tests:main; then failure="true"; fi

  local -a registries
  readarray -t registries < <(find "${roots}/scripts/local-clusters/registries" -type d -name '*\.*')
  for registry in "${registries[@]##"${roots}/scripts/local-clusters/registries/"}"; do
    if ! check_container "local-cache-${registry//./-}"; then failure="true"; fi
  done
  if ! check_container "local-resolve"; then failure="true"; fi

  if ! check_resolve; then failure="true"; fi

  if [[ "${failure}" == "true" ]]; then
    echo "error: preflight checks failure for regression tests" >&2
    exit 1
  fi
}
preflight.integration() {
  local failure="false"

  if ! check_image compliantkubernetes-apps-tests:main; then failure="true"; fi

  local -a registries
  readarray -t registries < <(find "${roots}/scripts/local-clusters/registries" -type d -name '*\.*')
  for registry in "${registries[@]##"${roots}/scripts/local-clusters/registries/"}"; do
    if ! check_container "local-cache-${registry//./-}"; then failure="true"; fi
  done
  if ! check_container "local-resolve"; then failure="true"; fi

  if ! check_resolve; then failure="true"; fi

  if [[ "${failure}" == "true" ]]; then
    echo "error: preflight checks failure for integration tests" >&2
    exit 1
  fi
}
preflight.end_to_end() {
  local failure="false"

  if ! check_image compliantkubernetes-apps-tests:main; then failure="true"; fi

  if [[ ! -d "${CK8S_CONFIG_PATH}" ]]; then
    echo "error: config path is not set" >&2
    failure="true"
  fi

  if [[ "${failure}" == "true" ]]; then
    echo "error: preflight checks failure for end-to-end tests" >&2
    exit 1
  fi
}

# Runs the setup for a given test suite.
# - Environment variables set during setup will be store into the file suite.env.
suite.setup() {
  local suite="${1:-}" file="${1:-}/setup_suite.bash"

  if [[ ! -d "${suite}" ]]; then
    echo "error: missing test suite ${suite##"${tests}/"}: aborting" >&2
    exit 1
  elif [[ ! -f "${file}" ]]; then
    echo "warn: missing test suite setup ${file##"${tests}/"}: skipping" >&2
    exit 0
  fi

  case "${suite##"${tests}/"}" in
  unit/*)
    preflight.unit
    ;;
  regression/*)
    preflight.regression
    ;;
  integration/*)
    preflight.integration
    ;;
  end-to-end/*)
    preflight.end-to-end
    ;;
  *)
    echo "error: invalid test target ${suite##"${tests}/"}: aborting" >&2
    exit 1
    ;;
  esac

  declare prevariables
  prevariables="$(env)"

  echo "info: sourcing test suite setup ${file##"${tests}/"}" >&2
  # shellcheck disable=SC1090
  source "${file}"

  if ! declare -F "setup_suite" &>/dev/null; then
    echo "warn: missing suite setup function: skipping" >&2
    exit 0
  fi

  echo "info: executing test suite setup ${file##"${tests}/"}" >&2
  setup_suite

  declare postvariables
  postvariables="$(env)"

  sort <<< "$prevariables"$'\n'"$postvariables" | uniq -u > "suite.env"

  echo "info: environment set during setup: suite.env"
  echo "- make sure to export these variables before running the test suite and teardown suite!"
  echo "- set -a; source suite.env; set +a"
}

# Runs the teardown for a given test suite.
# - Environment variables will be read from the file suite.env.
suite.teardown() {
  local suite="${1:-}" file="${1:-}/setup_suite.bash"

  if [[ ! -d "${suite}" ]]; then
    echo "error: missing test suite ${suite##"${tests}/"}: aborting" >&2
    exit 1
  elif [[ ! -f "${file}" ]]; then
    echo "warn: missing test suite teardown ${file##"${tests}/"}: skipping" >&2
    exit 0
  elif [[ ! -f "suite.env" ]]; then
    echo "warn: missing test suite environment suite.env: skipping" >&2
    exit 0
  fi

  set -a
  # shellcheck disable=SC1090,SC1091
  source "suite.env"
  set +a

  echo "info: sourcing test suite teardown ${file##"${tests}/"}" >&2
  # shellcheck disable=SC1090
  source "${file}"

  if ! declare -F "teardown_suite" &>/dev/null; then
    echo "warn: missing suite teardown function: skipping" >&2
    exit 0
  fi

  echo "info: executing test teardown setup ${file##"${tests}/"}" >&2
  teardown_suite

  rm "suite.env"
}

main() {
  case "${1:-}" in
  preflight)
    case "${2:-}" in
    unit)
      preflight.unit
      ;;
    regression)
      preflight.regression
      ;;
    integration)
      preflight.integration
      ;;
    end-to-end)
      preflight.end_to_end
      ;;
    *)
      echo "error: invalid argument for preflight" >&2
      exit 1
      ;;
    esac
    ;;
  suite)
    case "${2:-}" in
    setup)
      suite.setup "${@:3}"
      ;;
    teardown)
      suite.teardown "${@:3}"
      ;;
    *)
      echo "error: invalid argument for suite" >&2
      exit 1
      ;;
    esac
    ;;
  *)
    echo "error: invalid command" >&2
    exit 1
    ;;
  esac
}

main "${@}"
