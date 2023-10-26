#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if ! [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "only targets workload cluster, skipping"
      return
    fi

    if [[ "$(yq_dig wc .user.alertmanager.enabled)" != "true" ]]; then
      log_info "user-alertmanager not enabled, skipping"
      return
    fi

    if [[ -z "$(helm_do wc -n alertmanager get manifest user-alertmanager | yq4 'select(.kind == "Secret" and .metadata.name == "alertmanager-alertmanager")' 2>/dev/null)" ]]; then
      log_info "user-alertmanager/alertmanager-secret not managed, skipping"
      return
    fi

    log_info "creating a backup using velero of alertmanager namespace"
    kubectl_do wc apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  creationTimestamp: null
  name: apps-0-34-upgrade-alertmanager
  namespace: velero
spec:
  csiSnapshotTimeout: 0s
  hooks: {}
  includedNamespaces:
  - alertmanager
  metadata: {}
  ttl: 720h0m0s
status: {}
EOF

    if ! kubectl_do wc -n velero wait backups.velero.io apps-0-34-upgrade-alertmanager '--for=jsonpath=.status.phase=Completed' --timeout=120s; then
      log_fatal "user-alertmanager/alertmanager-secret failed to backup!"
    fi

    log_info "deleting managed user-alertmanager/alertmanager-secret"
    kubectl_do wc -n alertmanager delete secret alertmanager-alertmanager --ignore-not-found=true

    log_info "creating unmanaged user-alertmanager/alertmanager-secret"
    helmfile_do wc -l app=user-alertmanager sync --quiet
    helmfile_do wc -l app=user-alertmanager sync --quiet

    log_info "deleting unmanaged user-alertmanager/alertmanager-secret"
    kubectl_do wc -n alertmanager delete secret alertmanager-alertmanager --ignore-not-found=true

    log_info "restoring original user-alertmanager/alertmanager-secret"
    kubectl_do wc delete restores.velero.io apps-0-34-upgrade-alertmanager-execute --ignore-not-found=true
    kubectl_do wc apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  creationTimestamp: null
  name: apps-0-34-upgrade-alertmanager-execute
  namespace: velero
spec:
  backupName: apps-0-34-upgrade-alertmanager
  hooks: {}
  includedNamespaces:
  - '*'
status: {}
EOF

    if ! kubectl_do wc -n velero wait restores.velero.io apps-0-34-upgrade-alertmanager-execute '--for=jsonpath={.status.phase}=Completed' --timeout=120s; then
      log_fatal "user-alertmanager/alertmanager-secret failed to restore!"
    fi

    if ! kubectl_do wc -n alertmanager get secret alertmanager-alertmanager &>/dev/null; then
      log_fatal "user-alertmanager/alertmanager-secret missing after restore!"
    fi

    log_info "user-alertmanager/alertmanager-secret unmanaged"
    ;;

  rollback)
    if ! [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "only targets workload cluster, skipping"
      return
    fi

    if [[ "$(yq_dig wc .user.alertmanager.enabled)" != "true" ]]; then
      log_info "user-alertmanager not enabled, skipping"
      return
    fi

    if kubectl_do wc -n alertmanager get secret alertmanager-alertmanager &>/dev/null; then
      log_info "user-alertmanager/alertmanager-secret exists, skipping"
      return
    fi

    if ! kubectl_do wc -n velero get backups.velero.io apps-0-34-upgrade-alertmanager &>/dev/null; then
      log_fatal "user-alertmanager/alertmanager-secret has no backup!"
    fi

    log_warn "restoring original user-alertmanager/alertmanager-secret"
    kubectl_do wc delete restores.velero.io apps-0-34-upgrade-alertmanager-rollback --ignore-not-found=true
    kubectl_do wc apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  creationTimestamp: null
  name: apps-0-34-upgrade-alertmanager-rollback
  namespace: velero
spec:
  backupName: apps-0-34-upgrade-alertmanager
  hooks: {}
  includedNamespaces:
  - '*'
status: {}
EOF

    if ! kubectl_do wc -n velero wait restores.velero.io apps-0-34-upgrade-alertmanager-rollback '--for=jsonpath={.status.phase}=Completed' --timeout=120s; then
      log_fatal "user-alertmanager/alertmanager-secret failed to restore!"
    fi

    if ! kubectl_do wc -n alertmanager get secret alertmanager-alertmanager &>/dev/null; then
      log_fatal "user-alertmanager/alertmanager-secret missing after restore!"
    fi

    log_info "user-alertmanager/alertmanager-secret restored"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
