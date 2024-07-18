#!/usr/bin/env bash

# Executive commands for the test harness

set -euo pipefail

declare tests
tests="$(dirname "$(dirname "$(readlink -f "$0")")")"

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
  # check image is newer than dockerfile mod time
  echo "unit"
}
preflight.regression() {
  # check image is newer than dockerfile mod time
  # check that local cache is running
  # check that local resolve is running
  echo "regression"
}
preflight.integration() {
  # check image is newer than dockerfile mod time
  # check that local cache is running
  # check that local resolve is running
  echo "integration"
}
preflight.end_to_end() {
  # check image is newer than dockerfile mod time
  # check that local cache is running
  # check that local resolve is running
  # check that remote environment is set
  echo "end-to-end"
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
    ;;
  suite)
    case "${2:-}" in
    setup)
      suite.setup "${@:3}"
      ;;
    teardown)
      suite.teardown "${@:3}"
      ;;
    esac
    ;;
  esac
}

main "${@}"
