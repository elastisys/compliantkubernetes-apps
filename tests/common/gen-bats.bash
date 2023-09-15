#!/usr/bin/env bash

set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=tests/common/lib.bash
source "${HERE}/lib.bash"

# usage: render_args <cluster-name> <args-as-json-array>
render_args() {
  local cluster="${1:-}"
  local args="${2:-}"

  if [[ -z "${cluster}" ]]; then
    log_fatal "render args: missing cluster"
  elif [[ -z "${args#[]}" ]]; then
    # no args to render
    return
  fi

  for arg in $(yq4 -oy '.[]' <<< "${args}"); do
    if [[ "${arg}" =~ ^\. ]]; then
      # reference argument
      echo -n "\"\$(yq_dig \"${cluster}\" \"${arg}\")\""
    else
      # plain argument
      echo -n "\"${arg}\""
    fi
  done
}

# usage: render_conditions <cluster-name> <conditions-as-json-array>
render_conditions() {
  local cluster="${1:-}"
  local conditions="${2:-}"

  if [[ -z "${cluster}" ]]; then
    log_fatal "render conditions: missing cluster"
  elif [[ -z "${conditions#[]}" ]]; then
    # no conditions to render
    return
  fi

  for condition in $(yq4 -oy '.[]' <<< "${conditions}"); do
    echo "  continue_on \"${cluster}\" \"${condition}\""
  done
  echo ""
}

# usage: render_test <cluster-as-json-array> <namespaces-as-json-array> <conditions-as-json-array> <function-name> <target-name> <args-as-json-array>
render_test() {
  local clusters="${1:-}"
  local namespaces="${2:-}"
  local conditions="${3:-}"
  local function="${4:-}"
  local target="${5:-}"
  local args="${6:-}"

  if [[ -z "${clusters#[]}" ]]; then
    log_fatal "render test: missing clusters"
  elif [[ -z "${namespaces#[]}" ]]; then
    log_fatal "render test: missing namespaces"
  elif [[ -z "${function}" ]]; then
    log_fatal "render test: missing function"
  elif [[ -z "${target}" ]]; then
    log_fatal "render test: missing target"
  fi

  for cluster in $(yq4 -oy '.[]' <<< "${clusters}"); do
    for namespace in $(yq4 -oy '.[]' <<< "${namespaces}"); do
      echo ""
      echo "@test \"${name} - ${function/_/ } - ${cluster} / ${namespace} / ${target}\" {"
      render_conditions "${cluster}" "${conditions}"
      echo "  with_kubeconfig \"${cluster}\""
      echo "  with_namespace \"${namespace}\""
      echo ""
      echo "  ${function} \"${target}\" $(render_args "${cluster}" "${args}")"
      echo "}"
    done
  done
}

# usage: render_tests <test-as-json-object>...
render_tests() {
  local stage

  for test in "$@"; do
    # Intentionally creating subprocesses to ensure variables are reset after traversal
    (
      stage="$(yq4 '.clusters // []' <<< "${test}")"
      if [[ "${stage}" != "[]" ]]; then
        clusters="${stage}"
      fi

      stage="$(yq4 '.namespaces // []' <<< "${test}")"
      if [[ "${stage}" != "[]" ]]; then
        namespaces="${stage}"
      fi

      stage="$(yq4 '.condition // ""' <<< "${test}")"
      if [[ -n "${stage}" ]]; then
        if [[ -z "${conditions:-}" ]]; then
          conditions="\"${stage}\""
        else
          conditions="${conditions:-}, \"${stage}\""
        fi
      fi

      stage="$(yq4 '.function // ""' <<< "${test}")"
      if [[ -n "${stage}" ]]; then
        function="${stage}"
      fi

      stage="$(yq4 '.target // ""' <<< "${test}")"
      readarray -t tests <<< "$(yq4 -oj -I0 '.tests[] // []' <<< "${test}")"

      if [[ "${stage}" != "" ]]; then
        render_test "${clusters:-[]}" "${namespaces:-[]}" "[${conditions:-}]" "${function:-}" "${stage}" "$(yq4 -oj -I0 '.args // []' <<< "${test}")"
      elif [[ "${tests[*]}" != "[]" ]]; then
        render_tests "${tests[@]}"
      fi
    )
  done
}

# Generate bats test files from templates
main() {
  local file="${1:-}"

  if [[ -z "${file}" ]]; then
    log_fatal "missing file argument"
  elif ! [[ -f "${file}" ]]; then
    log_fatal "invalid file argument"
  fi

  file="$(readlink -f "${file}")"

  echo '#!/usr/bin/env bats'
  echo ''
  echo 'setup() {'
  echo '  load "../common/lib"'
  echo ''
  echo '  common_setup'
  echo '}'

  name="$(yq4 '.name' "${file}")"
  if [[ -z "${name}" ]]; then
    log.fatal "missing name of template"
  fi
  export name

  readarray -t tests <<< "$(yq4 -oj -I0 '.tests[]' "${file}")"
  render_tests "${tests[@]}"
}

main "$@"
