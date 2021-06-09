#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

secret="${CK8S_CONFIG_PATH}/secrets.yaml"
secret_tmp="${CK8S_CONFIG_PATH}/secrets_tmp.yaml"
sops_conf="${CK8S_CONFIG_PATH}/.sops.yaml"

update_script=$(mktemp -p /tmp update-script.XXXXXXXXXX.yaml)
cp "${here}/dex-update-script.yaml" "${update_script}"

# read all dex's static clients from ck8s cluster
static_clients_yaml=$(./bin/ck8s ops kubectl sc get secret dex --namespace dex --output jsonpath='{.data.config\\.yaml}' | base64 --decode | yq read - staticClients)

# delete clients that are part of a standard v0.16.x installation so only custom clients remain
static_clients_yaml=$(echo "$static_clients_yaml" | \
    yq delete - "id==kubelogin" | \
    yq delete - "id==grafana" | \
    yq delete - "id==grafana-ops" | \
    yq delete - "id==harbor" | \
    yq delete - "id==kibana-sso" | \
    yq delete - "id==grafana")

# merge custom clients from ck8s cluster into secrets config under additionalStaticClients
echo "$static_clients_yaml" | yq prefix - "[0].value" | yq merge --inplace "${update_script}" -
sops -d "${secret}" | \
    yq write --script "${update_script}" - | \
    sops --config "${sops_conf}" --input-type=yaml --output-type=yaml -e /dev/stdin > "${secret_tmp}"

cp "${secret}" "${secret}.bak"
mv "${secret_tmp}" "${secret}"

rm "${update_script}"
