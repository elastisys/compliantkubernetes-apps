#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# Add selector filters if covered by other snippets.
# Example: "app!=something"
declare -a skipped
skipped=(
  "app!=prometheus"
)
declare -a skipped_sc
skipped_sc=(
  "app!=opensearch"
)
declare -a skipped_wc
skipped_wc=(
  "app!=falco"
)

run() {
  case "${1:-}" in
  execute)
    local -a filters
    local selector

    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      filters=("${skipped[@]}" "${skipped_sc[@]}")
      selector="${filters[*]:-"app!=null"}"
      helmfile_upgrade sc "${selector// /,}"
    fi

    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      filters=("${skipped[@]}" "${skipped_wc[@]}")
      selector="${filters[*]:-"app!=null"}"
      helmfile_upgrade wc "${selector// /,}"
    fi
    ;;

  rollback)
    log_warn "rollback not implemented"

    # if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
    #   log_info "rollback operation on service cluster"
    # fi
    # if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
    #   log_info "rollback operation on workload cluster"
    # fi
    ;;

  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
