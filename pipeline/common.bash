#!/bin/bash

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

# Create CK8S_CONFIG_PATH if it does not exist and make it absolute
mkdir -p "${CK8S_CONFIG_PATH}"
CK8S_CONFIG_PATH=$(readlink -f "${CK8S_CONFIG_PATH}")
export CK8S_CONFIG_PATH

# We need to use this variable to override the default data path for helm
# TODO Change when this is closed https://github.com/helm/helm/issues/7919
export XDG_DATA_HOME="/root/.config"

config_update() {
    yq w -i "${CK8S_CONFIG_PATH}/${1}-config.yaml" "$2" "$3"
}

secrets_update() {
    local secrets_yaml="${CK8S_CONFIG_PATH}/secrets.yaml"
    # TODO: install editor in pipeline and set TERM properly to write using
    # `sops --set` instead.
    sops --config "${CK8S_CONFIG_PATH}/.sops.yaml" -d -i "${secrets_yaml}"
    yq w -i "${secrets_yaml}" "$1" "$2"
    sops --config "${CK8S_CONFIG_PATH}/.sops.yaml" -e -i "${secrets_yaml}"
}
