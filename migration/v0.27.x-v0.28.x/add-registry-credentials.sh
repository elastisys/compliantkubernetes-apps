#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

secret_config="${CK8S_CONFIG_PATH}/secrets.yaml"
sops_config="${CK8S_CONFIG_PATH}/.sops.yaml"

HARBOR_REGISTRY_PASS=$(pwgen -cns 20 1)
HARBOR_REGISTRY_PASS_HTPASSWD=$(htpasswd -bn "harbor_registry_user" "${HARBOR_REGISTRY_PASS}" | tr -d '\n')

sops --config "${sops_config}" --set '["harbor"]["registryPassword"] "'"${HARBOR_REGISTRY_PASS}"'"' "${secret_config}"
sops --config "${sops_config}" --set '["harbor"]["registryPasswordHtpasswd"] "'"${HARBOR_REGISTRY_PASS_HTPASSWD}"'"' "${secret_config}"
