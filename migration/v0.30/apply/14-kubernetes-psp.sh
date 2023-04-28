#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

apply() {
  condition="$(kubectl_do "${1}" -n kube-system get configmap kubeadm-config -o yaml | yq4 '.data.ClusterConfiguration | @yamld | .apiServer.extraArgs.enable-admission-plugins | split(",") | .[] | select(. == "PodSecurityPolicy")')"
  if [[ "${condition}" != "PodSecurityPolicy" ]]; then
    log_info "- skipping ${1} - Kubernetes PodSecurityPolicy admission not enabled"
    return
  fi

  log_info "- applying temporary bypass of vanilla Kubernetes PodSecurityPolicies in ${1}"

  for namespace in $(kubectl_do "${1}" get namespaces -l owner=operator -o name); do
    namespace="${namespace##namespace/}"

    if [[ "${namespace}" =~ ^kube-(node-lease|public|system)$ ]]; then
      continue
    fi

    if [[ -z "$(kubectl_do "${1}" -n "${namespace}" get rolebinding bypass-kubernetes-psp --ignore-not-found=true)" ]]; then
      log_info_no_newline "  - applying ${1}/$namespace - "
      kubectl_do "${1}" -n "${namespace}" create rolebinding bypass-kubernetes-psp --clusterrole psp:privileged --group "system:serviceaccounts:${namespace}"
    else
      log_info "  - skipping ${1}/$namespace - already exists"
    fi
  done
}

delete() {
  log_info "- deleting temporary bypass of vanilla Kubernetes PodSecurityPolicies in ${1}"

  for namespace in $(kubectl_do "${1}" get rolebindings -Aoyaml | yq4 '.items[] | select(.metadata.name == "bypass-kubernetes-psp") | .metadata.namespace'); do
    log_info_no_newline "  - deleting ${1}/$namespace - "
    kubectl_do "${1}" -n "${namespace}" delete rolebinding bypass-kubernetes-psp
  done
}

run() {
  case "${1:-}" in
  clean)
    delete sc
    delete wc
    ;;
  execute)
    apply sc
    apply wc
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
