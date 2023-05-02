#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    for CLUSTER in sc wc; do
      log_info "Uninstall starboard"
      helm_uninstall ${CLUSTER} monitoring starboard-operator
      helm_uninstall ${CLUSTER} monitoring starboard-psp-rbac
      log_info "Delete starboard crds"

      STAR_CRDS=$(kubectl_do ${CLUSTER} get crds -l app.kubernetes.io/managed-by=starboard -oname)

      if [ -n "$STAR_CRDS" ]; then
          # shellcheck disable=SC2086
          kubectl_do ${CLUSTER} delete --ignore-not-found=true $STAR_CRDS
      fi
    done

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
