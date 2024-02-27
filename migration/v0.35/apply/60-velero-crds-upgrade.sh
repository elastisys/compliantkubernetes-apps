#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "  - applying the Velero CRDs on sc"
      kubectl_do sc apply --server-side --force-conflicts -f "${ROOT}"/helmfile.d/upstream/vmware-tanzu/velero/crds

      helmfile_upgrade sc app=velero
    fi
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "  - applying the Velero CRDs on wc"
      kubectl_do wc apply --server-side --force-conflicts -f "${ROOT}"/helmfile.d/upstream/vmware-tanzu/velero/crds

      helmfile_upgrade wc app=velero
    fi
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
