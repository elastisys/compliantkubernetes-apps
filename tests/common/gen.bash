#!/usr/bin/env bash

set -euo pipefail

declare tests root
tests="$(dirname "$(dirname "$(readlink -f "$0")")")"
root="$(dirname "${tests}")"

cypress_gen() {
  local file

  file="$(readlink -f "$1")"

  local -a input

  readarray -t input < "${file}"

  local describe test

  local -a its

  for line in "${input[@]}"; do
    if [[ "${line}" =~ [[:space:]]*describe\( ]]; then
      describe="$(sed -n "s/describe([\"\']\(.\+\)[\"\'],.\+/\1/p" <<< "${line}")"
    elif [[ "${line}" =~ [[:space:]]+it\( ]]; then
      test="$(sed -n "s/[[:space:]]\+it([\"\']\(.\+\)[\"\'],.\+/\1/p" <<< "${line}")"

      its+=("${describe} ${test}")
    fi
  done

  file="${file/#${root}/\$\{ROOT\}}"

  echo '#!/usr/bin/env bats'
  echo ''
  echo 'setup_file() {'
  echo '  load "../common/lib"'
  echo ''
  echo "  cypress_setup \"${file}\""
  echo '}'
  echo ''
  echo 'setup() {'
  echo '  load "../common/lib"'
  echo ''
  echo '  common_setup'
  echo '}'

  for it in "${its[@]}"; do
    echo ''
    echo "@test \"${it}\" {"
    echo "  cypress_test \"${it}\""
    echo '}'
  done

  echo ''
  echo 'teardown_file() {'
  echo '  load "../common/lib"'
  echo ''
  echo "  cypress_teardown \"${file}\""
  echo '}'
}

cypress() {
  echo "generating cypress tests:" >&2

  local -a files

  if [[ "$#" -eq 0 ]]; then
    readarray -t files <<< "$(find "${tests}" -type f -name '*.cy.js')"
  else
    files=("${@/#/"$(dirname "${tests}")/"}")
  fi

  for file in "${files[@]}"; do
    echo "- ${file##"${root}/"}"

    cypress_gen "${file}" > "${file/%.cy.js/.gen.bats}"
  done
}

template() {
  echo "generating template tests:" >&2

  local -a files

  if [[ "$#" -eq 0 ]]; then
    readarray -t files <<< "$(find "${tests}" -type f -name '*.bats.gotmpl')"
  else
    files=("${@/#/"$(dirname "${tests}")/"}")
  fi

  local -a args

  for file in "${files[@]}"; do
    file="${file##"${root}/"}"

    echo "- ${file}"

    args+=("--file=${file}" "--out=${file/%.bats.gotmpl/.gen.bats}")
  done

  "${root}/scripts/run-from-container.sh" "docker.io/hairyhenderson/gomplate:v3.11.7-alpine" "${args[@]}"
}

case "${1:-}" in
all)
  echo "--- generating all tests ---" >&2
  cypress
  template
  ;;
cypress)
  cypress "${@:2}"
  ;;
template)
  template "${@:2}"
  ;;
*)
  echo "invalid or missing argument!" >&2
  exit 1
  ;;
esac
