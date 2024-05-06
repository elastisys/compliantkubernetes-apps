#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  clusters=("sc" "wc")
  if [[ "${CK8S_CLUSTER}" != "both" ]]; then
    clusters=("${CK8S_CLUSTER}")
  fi
  case "${1:-}" in
  execute)
    for cluster in "${clusters[@]}"; do
      log_info "  - updating helm annotations to default backupstoragelocation"
      kubectl_do "${cluster}" -n velero annotate backupstoragelocations.velero.io default "meta.helm.sh/release-name=velero"
      kubectl_do "${cluster}" -n velero annotate backupstoragelocations.velero.io default "meta.helm.sh/release-namespace=velero"
      kubectl_do "${cluster}" -n velero annotate backupstoragelocations.velero.io default "helm.sh/hook-"
      kubectl_do "${cluster}" -n velero annotate backupstoragelocations.velero.io default "helm.sh/hook-delete-policy-"

      log_info "  - updating helm annotations to velero-daily-backup schedules"
      kubectl_do "${cluster}" -n velero annotate schedules.velero.io velero-daily-backup "meta.helm.sh/release-name=velero"
      kubectl_do "${cluster}" -n velero annotate schedules.velero.io velero-daily-backup "meta.helm.sh/release-namespace=velero"
      kubectl_do "${cluster}" -n velero annotate schedules.velero.io velero-daily-backup "helm.sh/hook-"
      kubectl_do "${cluster}" -n velero annotate schedules.velero.io velero-daily-backup "helm.sh/hook-delete-policy-"

      log_info "  - applying the Velero CRDs on ${cluster}"
      kubectl_do "${cluster}" apply --server-side --force-conflicts -f "${ROOT}"/helmfile.d/upstream/vmware-tanzu/velero/crds

      helmfile_upgrade "${cluster}" app=velero
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
