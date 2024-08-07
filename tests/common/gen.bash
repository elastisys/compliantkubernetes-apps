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

  local bats cluster helmfile describe test

  local -a setup_file=() teardown_file=() its=()

  for line in "${input[@]}"; do
    if [[ "${line}" =~ "// bats" ]]; then
      bats="${line##// bats }"
    elif [[ "${line}" =~ "// cluster" ]]; then
      cluster="${line##// cluster }"
    elif [[ "${line}" =~ "// helmfile" ]]; then
      helmfile="${line##// helmfile }"
    elif [[ "${line}" =~ "// setup_file" ]]; then
      setup_file+=("${line##// setup_file }")
    elif [[ "${line}" =~ "// teardown_file" ]]; then
      teardown_file+=("${line##// teardown_file }")
    elif [[ "${line}" =~ [[:space:]]*describe\( ]]; then
      describe="$(sed -n "s/describe([\"\']\(.\+\)[\"\'],.\+/\1/p" <<< "${line}")"
    elif [[ "${line}" =~ [[:space:]]+it\( ]]; then
      test="$(sed -n "s/[[:space:]]\+it([\"\']\(.\+\)[\"\'],.\+/\1/p" <<< "${line}")"

      its+=("${describe} ${test}")
    fi
  done

  file="${file/#${root}/\$\{ROOT\}}"

  echo '#!/usr/bin/env bats'
  if [[ -n "${bats:-}" ]]; then
    echo ''
    echo "# bats ${bats}"
  fi
  echo ''
  echo 'setup_file() {'
  echo '  load "../../bats.lib.bash"'
  if [[ -n "${cluster:-}" ]] && [[ -n "${helmfile:-}" ]]; then
    echo "  auto_setup ${cluster} ${helmfile}"
  fi
  for step in "${setup_file[@]}"; do
    if [[ "${step}" == "// setup_file" ]]; then
      echo
    else
      echo "  ${step}"
    fi
  done
  echo ''
  echo "  cypress_setup \"${file}\""
  echo '}'
  echo ''
  echo 'setup() {'
  echo '  load "../../bats.lib.bash"'
  echo '  load_assert'
  echo '}'
  echo ''
  echo 'teardown_file() {'
  for step in "${teardown_file[@]}"; do
    if [[ "${step}" == "// teardown_file" ]]; then
      echo
    else
      echo "  ${step}"
    fi
  done
  echo "  cypress_teardown \"${file}\""
  if [[ -n "${cluster:-}" ]] && [[ -n "${helmfile:-}" ]]; then
    echo "  auto_teardown"
  fi
  echo '}'

  for it in "${its[@]}"; do
    echo ''
    echo "@test \"${it}\" {"
    echo "  cypress_test \"${it}\""
    echo '}'
  done
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

  if command -v gomplate > /dev/null; then
    pushd "${root}" &> /dev/null
    gomplate "${args[@]}"
    popd &> /dev/null
  else
    "${root}/scripts/run-from-container.sh" "docker.io/hairyhenderson/gomplate:v3.11.7-alpine" "${args[@]}"
  fi

  for file in "${files[@]}"; do
    # Ensure they are up to date according to make when gomplate does not have any changes
    touch "${file/%.bats.gotmpl/.gen.bats}"
  done

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
