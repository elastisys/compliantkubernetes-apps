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
    # Note: 00-template.sh will be skipped by the upgrade command
    log_info "no operation: this is a template"

    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "operation on service cluster"

      kubectl_do sc label crd taskruns.tekton.dev app.kubernetes.io/managed-by=Helm --overwrite
      kubectl_do sc annotate crd taskruns.tekton.dev meta.helm.sh/release-name=tekton-pipelines
      kubectl_do sc annotate crd taskruns.tekton.dev meta.helm.sh/release-namespace=tekton-pipelines

      kubectl_do sc label crd tasks.tekton.dev app.kubernetes.io/managed-by=Helm --overwrite
      kubectl_do sc annotate crd tasks.tekton.dev meta.helm.sh/release-name=tekton-pipelines
      kubectl_do sc annotate crd tasks.tekton.dev meta.helm.sh/release-namespace=tekton-pipelines

      kubectl_do sc label crd customruns.tekton.dev app.kubernetes.io/managed-by=Helm --overwrite
      kubectl_do sc annotate crd customruns.tekton.dev meta.helm.sh/release-name=tekton-pipelines
      kubectl_do sc annotate crd customruns.tekton.dev meta.helm.sh/release-namespace=tekton-pipelines

      kubectl_do sc label crd pipelineruns.tekton.dev app.kubernetes.io/managed-by=Helm --overwrite
      kubectl_do sc annotate crd pipelineruns.tekton.dev meta.helm.sh/release-name=tekton-pipelines
      kubectl_do sc annotate crd pipelineruns.tekton.dev meta.helm.sh/release-namespace=tekton-pipelines

      kubectl_do sc label crd pipelines.tekton.dev app.kubernetes.io/managed-by=Helm --overwrite
      kubectl_do sc annotate crd pipelines.tekton.dev meta.helm.sh/release-name=tekton-pipelines
      kubectl_do sc annotate crd pipelines.tekton.dev meta.helm.sh/release-namespace=tekton-pipelines

      kubectl_do sc label crd verificationpolicies.tekton.dev app.kubernetes.io/managed-by=Helm --overwrite
      kubectl_do sc annotate crd verificationpolicies.tekton.dev meta.helm.sh/release-name=tekton-pipelines
      kubectl_do sc annotate crd verificationpolicies.tekton.dev meta.helm.sh/release-namespace=tekton-pipelines

      kubectl_do sc label crd resolutionrequests.resolution.tekton.dev app.kubernetes.io/managed-by=Helm --overwrite
      kubectl_do sc annotate crd resolutionrequests.resolution.tekton.dev meta.helm.sh/release-name=tekton-pipelines
      kubectl_do sc annotate crd resolutionrequests.resolution.tekton.dev meta.helm.sh/release-namespace=tekton-pipelines

      helm_uninstall sc tekton-pipelines tekton-pipelines
      helmfile_apply sc app=tekton

      kubectl_delete sc crd tekton-pipelines runs.tekton.dev
      kubectl_delete sc crd tekton-pipelines clustertasks.tekton.dev
      kubectl_delete sc crd tekton-pipelines pipelineresources.tekton.dev

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
