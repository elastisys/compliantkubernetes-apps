#!/usr/bin/env bash

set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=test/common/lib.bash
source "${HERE}/lib.bash"

render_test() {
  if [[ "${1:-}" =~ ^([]|)$ ]]; then
    log_fatal "missing clusters"
  elif [[ "${2:-}" =~ ^([]|)$ ]]; then
    log_fatal "missing namespaces"
  elif [[ -z "${4:-}" ]]; then
    log_fatal "missing function"
  elif [[ -z "${5:-}" ]]; then
    log_fatal "missing target"
  fi


  for cluster in $(yq -oy '.[]' <<< "$1"); do
    for namespace in $(yq -oy '.[]' <<< "$2"); do

      local -a args
      if ! [[ "${6:-}" =~ ^([]|)$ ]]; then
        for arg in $(yq4 -oy '.[]' <<< "$6"); do
          if [[ "${arg}" =~ ^\. ]]; then
            args+=("\"\$(yq_dig \"${cluster}\" \"${arg}\")\"")
          else
            args+=("\"${arg}\"")
          fi
        done
      fi

      echo ""
      echo "@test \"${name} - ${4/_/ } - ${cluster} / ${namespace} / $5\" {"
      if ! [[ "${3:-}" =~ ^([]|)$ ]]; then
        for condition in $(yq -oy '.[]' <<< "$3"); do
          echo "  continue_on \"${cluster}\" \"${condition}\""
        done
        echo ""
      fi
      echo "  with_kubeconfig \"${cluster}\""
      echo "  with_namespace \"${namespace}\""
      echo ""
      echo "  $4 \"$5\" ${args[*]}"
      echo "}"
    done
  done
}

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
  if [[ -z "${1:-}" ]]; then
    log_fatal "missing file argument"
  elif ! [[ -f "$1" ]]; then
    log_fatal "invalid file argument"
  fi

  local template

  template="$(readlink -f "$1")"

  echo '#!/usr/bin/env bats'
  echo ''
  echo 'setup() {'
  echo '  load "../common/lib"'
  echo ''
  echo '  common_setup'
  echo '}'

  name="$(yq4 '.name' "${template}")"
  if [[ -z "${name}" ]]; then
    log.fatal "missing name of template"
  fi
  export name

  readarray -t tests <<< "$(yq4 -oj -I0 '.tests[]' "${template}")"
  render_tests "${tests[@]}"
}

main "$@"
