#!/usr/bin/env bash

# Welkin operator actions.

set -eu

here="$(dirname "$(readlink --canonicalize "$0")")"

# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
  echo "Usage: kubectl <wc|sc> ..." >&2
  echo "       kubecolor <wc|sc> ..." >&2
  echo "       helm <wc|sc> ..." >&2
  echo "       helmfile <wc|sc> ..." >&2
  exit 1
}

gatekeeper_cleanup() {
  local kubeconfig="$1" ns="${2:-gatekeeper-system}" rel="${3:-gatekeeper-templates}"

  with_kubeconfig "${kubeconfig}" bash -ceu '
    echo "Running Gatekeeper Cleanup Resources"

    kubectl -n '"$ns"' delete job '"$rel"'-wait --ignore-not-found || true
    kubectl -n '"$ns"' delete configmap '"$rel"'-wait --ignore-not-found || true
    kubectl -n '"$ns"' delete serviceaccount '"$rel"'-hook --ignore-not-found || true
    kubectl delete clusterrole '"$rel"'-wait --ignore-not-found || true
    kubectl delete clusterrolebinding '"$rel"'-wait --ignore-not-found || true
  '
}

# Run arbitrary kubecolor commands as cluster admin.
ops_kubecolor() {
  case "${1}" in
  sc) kubeconfig="${config[kube_config_sc]}" ;;
  wc) kubeconfig="${config[kube_config_wc]}" ;;
  *) usage ;;
  esac
  shift
  with_kubeconfig "${kubeconfig}" kubecolor "${@}"
}

# Run arbitrary kubectl commands as cluster admin.
ops_kubectl() {
  case "${1}" in
  sc) kubeconfig="${config[kube_config_sc]}" ;;
  wc) kubeconfig="${config[kube_config_wc]}" ;;
  *) usage ;;
  esac
  shift
  with_kubeconfig "${kubeconfig}" kubectl "${@}"
}

# Run arbitrary helm commands as cluster admin.
ops_helm() {
  case "${1}" in
  sc) kubeconfig="${config[kube_config_sc]}" ;;
  wc) kubeconfig="${config[kube_config_wc]}" ;;
  *) usage ;;
  esac
  shift
  with_kubeconfig "${kubeconfig}" helm "${@}"
  # Detect uninstall gatekeeper-templates
  if [[ "$1" == "uninstall" ]]; then
    local rel="$2"
    if [[ "$rel" == "gatekeeper-templates" || "$rel" == gatekeeper* ]]; then
      gatekeeper_cleanup "${kubeconfig}" "gatekeeper-system" "${rel:-gatekeeper-templates}"
    fi
  fi
}

# Run arbitrary Helmfile commands as cluster admin.
ops_helmfile() {
  # Skip validation when fetching completions
  if [ "$2" == "__complete" ]; then
    config_load "$1" --skip-validation
  else
    config_load "$1"
  fi

  case "${1}" in
  sc)
    cluster="service_cluster"
    kubeconfig="${config[kube_config_sc]}"
    ;;
  wc)
    cluster="workload_cluster"
    kubeconfig="${config[kube_config_wc]}"
    ;;
  *) usage ;;
  esac

  shift
  with_kubeconfig "${kubeconfig}" \
    helmfile -f "${here}/../helmfile.d/" -e ${cluster} "${@}"

  if [[ "$1" =~ ^(delete|destroy)$ ]]; then
    if printf '%q ' "$@" | grep -Eq -- '-l[[:space:]]*(app|component)=gatekeeper|name=gatekeeper-templates'; then
      gatekeeper_cleanup "${kubeconfig}" "gatekeeper-system" "gatekeeper-templates"
    fi
  fi
}

# Run arbitrary Velero commands as cluster admin.
ops_velero() {
  case "${1}" in
  sc) kubeconfig="${config[kube_config_sc]}" ;;
  wc) kubeconfig="${config[kube_config_wc]}" ;;
  *) usage ;;
  esac
  shift
  with_kubeconfig "${kubeconfig}" velero "${@}"
}

case "${1}" in
kubectl)
  shift
  ops_kubectl "${@}"
  ;;
kubecolor)
  shift
  ops_kubecolor "${@}"
  ;;
helm)
  shift
  ops_helm "${@}"
  ;;
helmfile)
  shift
  ops_helmfile "${@}"
  ;;
velero)
  shift
  ops_velero "${@}"
  ;;
*) usage ;;
esac
