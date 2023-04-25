#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

update_hnc_namespaces_label() {
  log_info "--- Waiting for hnc-controller-manager"
  kubectl_do wc wait pods -n hnc-system -l app.kubernetes.io/component=hnc-controller-manager --for condition=Ready --timeout=90s

  readarray userNamespaces < <(yq4 '.user.namespaces[]' $CK8S_CONFIG_PATH/wc-config.yaml)
  readarray userNamespacesWithHigherPSALevel < <(yq4 '.user.constraints | keys | .[]' $CK8S_CONFIG_PATH/wc-config.yaml)

  for i in "${userNamespacesWithHigherPSALevel[@]}"; do
    userNamespaces=(${userNamespaces[@]//*$i*/})
  done

  for i in "${userNamespaces[@]}"; do
    ## Trigger the new mutation on already existing hnc namespaces
    kubectl_do wc get hierarchyconfigurations -n ${i} hierarchy -o yaml |
      yq4 '.metadata.generation += 1' |
      kubectl_do wc apply -f -
  done
}

run() {
  case "${1:-}" in
  execute)
    log_info "--- applying user-rbac for workload cluster"
    helmfile_upgrade wc app=user-rbac

    log_info "--- applying HNC for workload cluster"
    helmfile_upgrade wc group=hnc

    log_info "--- updating HNC managed namespaces with PSA labels for workload cluster"
    update_hnc_namespaces_label
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
