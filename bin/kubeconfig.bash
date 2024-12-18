#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
  echo "Usage: kubeconfig <user| dev <serviceaccount> | admin <wc|sc> [cluster_name]>" >&2
  exit 1
}

[ -z "${1:-}" ] && usage

get_user_server() {
  (
    with_kubeconfig "${kubeconfig}" \
      kubectl config view -o jsonpath="{.clusters[0].cluster.server}"
  )
}

set_cluster() {
  user_kubeconfig=$1

  user_server=$(get_user_server)
  user_certificate_authority=/tmp/user-authority.pem
  append_trap "rm ${user_certificate_authority}" EXIT
  (
    with_kubeconfig "${kubeconfig}" \
      kubectl config view --raw \
      -o jsonpath="{.clusters[0].cluster.certificate-authority-data}" |
      base64 --decode >${user_certificate_authority}
  )

  kubectl --kubeconfig="${user_kubeconfig}" config set-cluster "${cluster_name}" \
    --server="${user_server}" \
    --certificate-authority="${user_certificate_authority}" --embed-certs=true
}

set_dex_credentials() {
  user_kubeconfig=$1
  name=$2
  cluster_name=$3

  config_load sc
  cluster_config="${config[config_file_sc]}"
  base_domain=$(yq4 '.global.baseDomain' "${cluster_config}")

  kubectl --kubeconfig="${user_kubeconfig}" config set-credentials "${name}@${cluster_name}" \
    --exec-command=kubectl \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-arg=oidc-login \
    --exec-arg=get-token \
    --exec-arg=--oidc-issuer-url="https://dex.${base_domain}" \
    --exec-arg=--oidc-client-id=kubelogin \
    --exec-arg=--oidc-client-secret="$(sops -d --extract '["dex"]["kubeloginClientSecret"]' "${secrets[secrets_file]}")" \
    --exec-arg=--oidc-extra-scope=email \
    --exec-arg=--oidc-extra-scope=groups
}

set_context() {
  user_kubeconfig=$1
  cluster_name=$2
  context_name=$3
  user_name=$4
  context_namespace=$5

  kubectl --kubeconfig="${user_kubeconfig}" config set-context \
    "${context_name}" \
    --user "${user_name}@${cluster_name}" --cluster="${cluster_name}" --namespace="${context_namespace}"
}

use_context() {
  user_kubeconfig=$1
  cluster_name=$2

  kubectl --kubeconfig="${user_kubeconfig}" config use-context \
    "${cluster_name}"
}

case "${1}" in
user)
  config_load wc
  cluster_config="${config[config_file_wc]}"
  kubeconfig="${config[kube_config_wc]}"
  user_kubeconfig=${CK8S_CONFIG_PATH}/user/secret/kubeconfig.yaml
  ;;
dev)
  serviceAccount="${2:-}"
  if [ -z "${serviceAccount}" ]; then
    echo "Error: Service account name is needed" >&2
    usage
  fi

  config_load wc
  cluster_config="${config[config_file_wc]}"
  kubeconfig="${config[kube_config_wc]}"

  if [[ ! $(with_kubeconfig "${kubeconfig}" kubectl get serviceaccount "${serviceAccount}" 2>/dev/null) ]]; then
    log_error "Service account ${serviceAccount} not found"
    log_error " Add service account ${serviceAccount} in your wc-config"
    log_error " Then apply app=user-rbac"
    exit
  fi

  log_info "Adding dev ${serviceAccount} context to wc-config"

  token=$(with_kubeconfig "${kubeconfig}" kubectl get secrets secret-"${serviceAccount}" -ojsonpath="{.data.token}" | base64 -d)
  cluster_name=$(yq4 '.global.clusterName' "${cluster_config}")

  kubectl --kubeconfig="${kubeconfig}" config set-credentials "${serviceAccount}@${cluster_name}" \
    --token="${token}"

  set_context "${kubeconfig}" "${cluster_name}" "${serviceAccount}" "${serviceAccount}" "default"

  log_info "Dev context finished"
  exit
  ;;
admin)
  case "${2:-}" in
  sc)
    config_load sc
    cluster_config="${config[config_file_sc]}"
    kubeconfig="${config[kube_config_sc]}"
    ;;
  wc)
    config_load wc
    cluster_config="${config[config_file_wc]}"
    kubeconfig="${config[kube_config_wc]}"
    ;;
  *) usage ;;
  esac
  cluster="$2"
  if [[ $# -gt 2 ]]; then
    kubeconfig="${state_path}/kube_config_$3.yaml"
    cluster="$3"
  fi
  user_kubeconfig=${CK8S_CONFIG_PATH}/.state/admin-kubeconfig-${cluster}.yaml
  ;;
*) usage ;;
esac

if [[ ! -f "${kubeconfig}" ]]; then
  log_error "${kubeconfig} not found"
  usage
fi

log_info "Creating kubeconfig for the ${1}"

cluster_name=$(yq4 '.global.clusterName' "${cluster_config}")

set_cluster "${user_kubeconfig}"
set_dex_credentials "${user_kubeconfig}" "${1}" "${cluster_name}"

# Create context with relevant namespace
# Pick the first namespace
if [[ ${1} == "user" ]]; then
  context_namespace=$(yq4 '.user.namespaces[0]' "${config[config_file_wc]}")
else
  context_namespace="default"
fi

set_context "${user_kubeconfig}" "${cluster_name}" "${cluster_name}" "${1}" "${context_namespace}"
use_context "${user_kubeconfig}" "${cluster_name}"

log_info "User kubeconfig can now be found at ${user_kubeconfig}."
