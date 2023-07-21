#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# Add selector filters if covered by other snippets.
# Example: "app!=something"
declare -a skipped
skipped=(
)
declare -a skipped_sc
skipped_sc=(
  "app!=rclone-sync"
  "app!=kube-prometheus-stack"
  "app!=grafana-dashboards"
)
declare -a skipped_wc
skipped_wc=(
)

run() {
  case "${1:-}" in
  execute)
    local -a filters
    local selector

    filters=("${skipped[@]}" "${skipped_sc[@]}")
    selector="${filters[*]:-"app!=null"}"
    helmfile_upgrade sc "${selector// /,}"
    filters=("${skipped[@]}" "${skipped_wc[@]}")
    selector="${filters[*]:-"app!=null"}"
    helmfile_upgrade wc "${selector// /,}"
    ;;

  rollback)
    log_warn "rollback not implemented"
    ;;

  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
