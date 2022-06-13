#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
    echo "Usage: kubeconfig" >&2
    exit 1
}

config_load wc
cluster_config="${config[config_file_wc]}"
kubeconfig="${config[kube_config_wc]}"
user_kubeconfig=${CK8S_CONFIG_PATH}/user/kubeconfig.yaml

if [[ ! -f "${kubeconfig}" ]]; then
    log_error "${kubeconfig} not found"
    usage
fi

get_user_server() {
    (
        with_kubeconfig "${kubeconfig}" \
            kubectl config view -o jsonpath="{.clusters[0].cluster.server}"
    )
}

log_info "Creating kubeconfig for the ${1}"

cluster_name=$(yq r "${cluster_config}" 'global.clusterName')
base_domain=$(yq r "${cluster_config}" 'global.baseDomain')

# Get server and certificate from the admin kubeconfig
user_server=$(get_user_server)
user_certificate_authority=/tmp/user-authority.pem
append_trap "rm ${user_certificate_authority}" EXIT
(
    with_kubeconfig "${kubeconfig}" \
        kubectl config view --raw \
            -o jsonpath="{.clusters[0].cluster.certificate-authority-data}" \
            | base64 --decode > ${user_certificate_authority}
)

kubectl --kubeconfig="${user_kubeconfig}" config set-cluster "${cluster_name}" \
    --server="${user_server}" \
    --certificate-authority="${user_certificate_authority}" --embed-certs=true
kubectl --kubeconfig="${user_kubeconfig}" config set-credentials "${1}@${cluster_name}" \
    --exec-command=kubectl \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-arg=oidc-login \
    --exec-arg=get-token \
    --exec-arg=--oidc-issuer-url="https://dex.${base_domain}" \
    --exec-arg=--oidc-client-id=kubelogin \
    --exec-arg=--oidc-client-secret="$(sops -d --extract '["dex"]["kubeloginClientSecret"]' "${secrets[secrets_file]}")" \
    --exec-arg=--oidc-extra-scope=email \
    --exec-arg=--oidc-extra-scope=groups

# Create context with relavant namespace
# Pick the first namespace

context_namespace=$(yq r "${config[config_file_wc]}" 'user.namespaces[0]')

kubectl --kubeconfig="${user_kubeconfig}" config set-context \
    "${cluster_name}" \
    --user "${1}@${cluster_name}" --cluster="${cluster_name}" --namespace="${context_namespace}"
kubectl --kubeconfig="${user_kubeconfig}" config use-context \
    "${cluster_name}"

log_info "User kubeconfig can now be found at ${user_kubeconfig}."
