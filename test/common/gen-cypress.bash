#!/usr/bin/env bash

set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=test/common/lib.bash
source "${HERE}/lib.bash"

# Generate bats test files for running cypress tests
main() {
  if [[ -z "${1:-}" ]]; then
    log_fatal "missing file argument"
  elif ! [[ -f "$1" ]]; then
    log_fatal "invalid file argument"
  fi

  local cypress_file

  cypress_file="$(readlink -f "$1")"

  readarray -t input < "${cypress_file}"

  local group
  local test

  local -a tests

  for line in "${input[@]}"; do
    if [[ "${line}" =~ [[:space:]]*describe\( ]]; then
      group="$(sed -n "s/describe([\"\']\([[:alnum:] ]\+\)[\"\'],.\+/\1/p" <<< "${line}")"
    elif [[ "${line}" =~ [[:space:]]+it\( ]]; then
      test="$(sed -n "s/[[:space:]]\+it([\"\']\([[:alnum:] ]\+\)[\"\'],.\+/\1/p" <<< "${line}")"

      tests+=("${group} ${test}")
    fi
  done

  cypress_file="${cypress_file/#"${ROOT}"/\$\{ROOT\}}"

  echo '#!/usr/bin/env bats'
  echo ''
  echo 'setup_file() {'
  echo '  load "../common/lib"'
  echo ''
  echo "  cypress_setup \"${cypress_file}\""
  echo '}'
  echo ''
  echo 'setup() {'
  echo '  load "../common/lib"'
  echo ''
  echo '  common_setup'
  echo '}'

  for test in "${tests[@]}"; do
    echo ''
    echo "@test \"${test}\" {"
    echo "  cypress_test \"${test}\""
    echo '}'
  done

  echo ''
  echo 'teardown_file() {'
  echo '  load "../common/lib"'
  echo ''
  echo "  cypress_teardown \"${cypress_file}\""
  echo '}'
}

main "$@"
