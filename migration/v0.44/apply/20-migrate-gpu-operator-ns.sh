#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# functions currently available in the library:
#   - logging:
#     - log_info(_no_newline) <message>
#     - log_warn(_no_newline) <message>
#     - log_error(_no_newline) <message>
#     - log_fatal <message> # this will call "exit 1"
#
#   - kubectl
#     # Use kubectl with kubeconfig set
#     - kubectl_do <sc|wc> <kubectl args...>
#     # Perform kubectl delete, will not cause errors if the resource is missing
#     - kubectl_delete <sc|wc> <resource> <namespace> <name>
#
#   - helm
#     # Use helm with kubeconfig set
#     - helm_do <sc|wc> <helm args...>
#     # Checks if a release is installed
#     - helm_installed <sc|wc> <namespace> <release>
#     # Uninstalls a release if it is installed
#     - helm_uninstall <sc|wc> <namespace> <release>
#
#   - helmfile
#     # Use helmfile with kubeconfig set
#     - helmfile_do <sc|wc> <helmfile args...>
#     # For selector args all will be prefixed with "-l"
#     # List releases matching the selector
#     - helmfile_list <sc|wc> <selectors...>
#     # Apply releases matching the selector
#     - helmfile_apply <sc|wc> <selectors...>
#     # Check for changes on releases matching the selector
#     - helmfile_change <sc|wc> <selectors...>
#     # Destroy releases matching the selector
#     - helmfile_destroy <sc|wc> <selectors...>
#     # Replaces the releases matching the selector, performing destroy and apply on each release individually
#     - helmfile_replace <sc|wc> <selectors...>
#     # Upgrades the releases matching the selector, performing automatic rollback on failure set "CK8S_ROLLBACK=false" to disable
#     - helmfile_upgrade <sc|wc> <selectors...>

run() {
  case "${1:-}" in
  execute)
    log_info "Migrating gpu-operator namespace to be managed by Helm if it already exists"

    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      if kubectl_do wc get ns gpu-operator >/dev/null 2>&1; then
        log_info "Namespace gpu-operator exists, migrating namespace to be managed by Helm"
        kubectl_do wc label ns gpu-operator app.kubernetes.io/managed-by=Helm
        kubectl_do wc annotate ns gpu-operator meta.helm.sh/release-name=admin-namespaces
        kubectl_do wc annotate ns gpu-operator meta.helm.sh/release-namespace=kube-system
        helmfile_do wc -l app=admin-namespaces sync
      else
        log_info "Namespace gpu-operator does not exist, skipping"
      fi
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
