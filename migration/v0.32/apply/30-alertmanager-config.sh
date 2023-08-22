#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

wait_velero_backup() {
  TIMEOUT=15
  while [ $TIMEOUT -gt 0 ]; do
    backup_status=$(kubectl_do wc get backup -n velero alertmanager-config-backup -o yaml | yq4 '.status.phase')
    if [ "${backup_status}" == Completed ]; then
      log_info "- backup completed"
      break
    fi
    TIMEOUT=$((TIMEOUT - 1))
    sleep 5
  done
  if [ $TIMEOUT -eq 0 ]; then
    log_warn "- the velero backup didn't complete"
  fi
}

run() {
  case "${1:-}" in
  execute)
    # Note: 00-template.sh will be skipped by the upgrade command
    log_info "- backing-up wc alertmanager namespace using velero"
    kubectl_do wc apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  creationTimestamp: null
  name: alertmanager-config-backup
  namespace: velero
spec:
  hooks: {}
  includedNamespaces:
  - alertmanager
  metadata: {}
  ttl: 720h0m0s
status: {}
EOF
    log_info "- waiting for the backup to be complete"
    wait_velero_backup

    log_info "- adding the new annotations to wc alertmanager secret"
    kubectl_do wc annotate secret -n alertmanager alertmanager-alertmanager helm.sh/hook- helm.sh/hook-weight- app.kubernetes.io/managed-by=Helm meta.helm.sh/release-name=user-alertmanager meta.helm.sh/release-namespace=alertmanager --overwrite
    kubectl_do wc label secret -n alertmanager alertmanager-alertmanager app.kubernetes.io/managed-by=Helm --overwrite

    helmfile_upgrade wc app=user-alertmanager
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
