#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1090
source "${here}/common.bash"
config_load wc

: "${secrets[kube_config_wc]:?Missing workload cluster kubeconfig}"
: "${secrets[secrets_file]:?Missing workload cluster secrets}"
: "${config[config_file_wc]:?Missing workload cluster configuration}"

get_user_server() {
    (
        with_kubeconfig "${secrets[kube_config_wc]}" \
            kubectl config view -o jsonpath="{.clusters[0].cluster.server}"
    )
}

log_info "Creating kubeconfig for the user"

environment_name=$(yq r "${config[config_file_wc]}" 'global.environmentName')
cloud_provider=$(yq r "${config[config_file_wc]}" 'global.cloudProvider')
base_domain=$(yq r "${config[config_file_wc]}" 'global.baseDomain')

# Get server and certificate from the admin kubeconfig
cluster_name="${environment_name}_${cloud_provider}"
user_server=$(get_user_server)
user_certificate_authority=/tmp/user-authority.pem
append_trap "rm ${user_certificate_authority}" EXIT
(
    with_kubeconfig "${secrets[kube_config_wc]}" \
        kubectl config view --raw \
            -o jsonpath="{.clusters[0].cluster.certificate-authority-data}" \
            | base64 --decode > ${user_certificate_authority}
)

user_kubeconfig=${CK8S_CONFIG_PATH}/user/kubeconfig.yaml

append_trap "sops_encrypt ${user_kubeconfig}" EXIT
if [ -f "${user_kubeconfig}" ]; then
    sops_decrypt "${user_kubeconfig}"
fi

kubectl --kubeconfig="${user_kubeconfig}" config set-cluster "${cluster_name}" \
    --server="${user_server}" \
    --certificate-authority="${user_certificate_authority}" --embed-certs=true
kubectl --kubeconfig="${user_kubeconfig}" config set-credentials "user@${cluster_name}" \
    --exec-command=kubectl \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-arg=oidc-login \
    --exec-arg=get-token \
    --exec-arg=--oidc-issuer-url="https://dex.${base_domain}" \
    --exec-arg=--oidc-client-id=kubelogin \
    --exec-arg=--oidc-client-secret="$(sops -d --extract '["dex"]["kubeloginClientSecret"]' "${secrets[secrets_file]}")" \
    --exec-arg=--oidc-extra-scope=email

# Create context with relavant namespace
# Pick the first namespace
context_namespace=$(yq r "${config[config_file_wc]}" 'user.namespaces[0]')
kubectl --kubeconfig="${user_kubeconfig}" config set-context \
    "${cluster_name}" \
    --user "user@${cluster_name}" --cluster="${cluster_name}" --namespace="${context_namespace}"
kubectl --kubeconfig="${user_kubeconfig}" config use-context \
    "${cluster_name}"

log_info "User kubeconfig can now be found at ${user_kubeconfig}."
