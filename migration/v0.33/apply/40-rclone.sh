#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    log_info "Removing old rclone-sync cronjobs"
    old_cronjobs=$(kubectl_do sc get cronjobs.batch -n kube-system -l app=rclone-sync --output=jsonpath={.items..metadata.name})
    for cronjob in $old_cronjobs; do
      kubectl_delete sc cronjobs.batch kube-system "$cronjob"
    done
    helmfile_apply sc app=rclone-sync
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
