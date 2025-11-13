#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)

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
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
