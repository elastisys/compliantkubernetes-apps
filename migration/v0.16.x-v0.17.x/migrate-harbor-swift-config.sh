#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

config="${CK8S_CONFIG_PATH}/sc-config.yaml"
secrets="${CK8S_CONFIG_PATH}/secrets.yaml"
sops_conf="${CK8S_CONFIG_PATH}/.sops.yaml"

migrate_swift_config_option() {
    local option="${1}"

    local old_option="citycloud.${option}"
    local new_option="harbor.persistence.swift.${option}"

    local value
    value="$(yq read "${config}" "${old_option}")"

    [ -z "${value}" ] && return

    yq write --inplace "${config}" "${new_option}" "${value}"

    yq delete --inplace "${config}" "${old_option}"
}

migrate_swift_secret_option() {
    local option="${1}"

    local old_option="citycloud.${option}"
    local new_option="harbor.persistence.swift.${option}"

    local value
    value="$(sops -d "${secrets}" | yq read - "${old_option}")"

    [ -z "${value}" ] && return

    sops -d "${secrets}" |
        yq write - "${new_option}" "${value}" | \
        yq delete - "${old_option}" | \
        sops --config "${sops_conf}" --input-type=yaml --output-type=yaml -e /dev/stdin > "${secrets}.tmp" && \
        mv "${secrets}.tmp" "${secrets}"
}

# Migrate sc-config.yaml

migrate_swift_config_option identityApiVersion
migrate_swift_config_option authURL
migrate_swift_config_option regionName
migrate_swift_config_option projectDomainName
migrate_swift_config_option userDomainName
migrate_swift_config_option projectName
migrate_swift_config_option projectID
migrate_swift_config_option tenantName
migrate_swift_config_option authVersion
yq delete --inplace "${config}" citycloud

# Migrate secrets.yaml

migrate_swift_secret_option username
migrate_swift_secret_option password
sops -d "${secrets}" | yq delete - citycloud | \
    sops --config "${sops_conf}" --input-type=yaml --output-type=yaml -e /dev/stdin > "${secrets}.tmp" && \
    mv "${secrets}.tmp" "${secrets}"
