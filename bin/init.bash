#!/bin/bash

# This script takes care of initializing a CK8S configuration path for apps.
# It writes the default configuration files to the config path and generates
# some defaults where applicable.
# It's not to be executed on its own but rather via `ck8s init`.

set -eu -o pipefail

: "${CK8S_CLOUD_PROVIDER:?Missing CK8S_CLOUD_PROVIDER}"
: "${CK8S_ENVIRONMENT_NAME:?Missing CK8S_ENVIRONMENT_NAME}"
# Make sure flavor is set
export CK8S_FLAVOR="${CK8S_FLAVOR:-dev}"
here="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=1090
source "${here}/common.bash"
: "${config_defaults_path:?Missing config defaults path}"
: "${config[config_file_wc]:?Missing workload cluster config file}"
# shellcheck disable=2154
: "${secrets[secrets_file]:?Missing secrets file}"
: "${sops_config:?Missing sops config}"
: "${state_path:?Missing state path}"

validate_cloud "${CK8S_CLOUD_PROVIDER}"

# Validate the flavor
if [ "${CK8S_FLAVOR}" != "dev" ] &&
   [ "${CK8S_FLAVOR}" != "prod" ]; then
    log_error "ERROR: Unsupported flavor: ${CK8S_FLAVOR}"
    exit 1
fi

generate_sops_config() {
    if [ "${CK8S_PGP_FP+x}" != "" ]; then
        fingerprint="${CK8S_PGP_FP}"
    elif [ "${CK8S_PGP_UID+x}" != "" ]; then
        fingerprint=$(gpg --list-keys --with-colons "${CK8S_PGP_UID}" | \
                      awk -F: '$1 == "fpr" {print $10;}' | head -n 1)
        if [ -z "${fingerprint}" ]; then
            log_error "ERROR: Unable to get fingerprint from gpg keyring."
            log_error "CK8S_PGP_UID=${CK8S_PGP_UID}"
            exit 1
        fi
    else
        log_error "ERROR: CK8S_PGP_FP and CK8S_PGP_UID can't both be unset"
        exit 1
    fi

    log_info "Initializing SOPS config with PGP fingerprint: ${fingerprint}"

    sops_config_write_fingerprints "${fingerprint}"
}

# Only writes value if it is set to "set-me"
# Usage:
# replace_set_me <file> <field> <value>
replace_set_me(){
    if [[ $# -ne 3 ]]; then
        log_error "ERROR: number of args in replace_set_me must be 3. #=[$#]"
        exit 1
    fi
    if [[ $(yq r "$1" "$2") == "set-me" ]]; then
       yq w -i "$1" "$2" "$3"
    fi

}

generate_base_sc_config() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in generate_base_sc_config must be 1. #=[$#]"
        exit 1
    fi
    file=$1
    tmpfile=$(mktemp)

    envsubst > "$tmpfile" < "${config_defaults_path}/config/sc-config.yaml"
    if [[ ${CK8S_CLOUD_PROVIDER} == "citycloud" ]]; then
        yq merge -i "$tmpfile" "${config_defaults_path}/config/citycloud.yaml"
    fi
    yq merge -i --overwrite "$tmpfile" "${config_defaults_path}/config/flavors/${CK8S_FLAVOR}-sc.yaml"
    if [[ -f $file ]]; then
        yq merge -i "$file" "$tmpfile"
    else
        cat "$tmpfile" > "$file"
    fi
}

generate_base_wc_config() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in generate_base_wc_config must be 1. #=[$#]"
        exit 1
    fi
    file=$1
    tmpfile=$(mktemp)

    envsubst > "$tmpfile" < "${config_defaults_path}/config/wc-config.yaml"
    yq merge -i --overwrite "$tmpfile" "${config_defaults_path}/config/flavors/${CK8S_FLAVOR}-wc.yaml"
    if [[ -f $file ]]; then
        yq merge -i "$file" "$tmpfile"
    else
        cat "$tmpfile" > "$file"
    fi
}

# Usage: set_storage_class <config-file>
set_storage_class() {
    file=$1
    if [[ ! -f "${file}" ]]; then
        log_error "ERROR: invalid file - $file"
        exit 1
    fi
    case ${CK8S_CLOUD_PROVIDER} in
        safespring | citycloud)
          storage_class=cinder-storage
          es_storage_class=cinder-storage
          ;;

        exoscale)
          storage_class=nfs-client
          es_storage_class=local-storage
          ;;

        aws)
          storage_class=ebs-gp2
          es_storage_class=ebs-gp2
          ;;

    esac
    replace_set_me "$1" 'global.storageClass' "$storage_class"
    # Only write if field exists already
    if yq r -e "$file" 'elasticsearch.storageClass' > /dev/null 2> /dev/null; then
       yq w -i "$file" 'elasticsearch.storageClass' "$es_storage_class"
    fi
}

# Usage: set_nginx_config <config-file>
set_nginx_config() {
    file=$1
    if [[ ! -f "${file}" ]]; then
        log_error "ERROR: invalid file - $file"
        exit 1
    fi
    case ${CK8S_CLOUD_PROVIDER} in
        citycloud | exoscale)
          use_proxy_protocol=false
          use_host_port=true
          service_enabled=false
          ;;

        safespring)
          use_proxy_protocol=true
          use_host_port=true
          service_enabled=false
          ;;

        aws)
          use_proxy_protocol=false
          use_host_port=false
          service_enabled=true
          service_type=LoadBalancer
          service_annotations='service.beta.kubernetes.io/aws-load-balancer-type: nlb'
          replace_set_me "$1" 'nginxIngress.controller.service.type' "$service_type"
          replace_set_me "$1" 'nginxIngress.controller.service.annotations' "$service_annotations"
          ;;

    esac
    replace_set_me "$1" 'nginxIngress.controller.config.useProxyProtocol' "$use_proxy_protocol"
    replace_set_me "$1" 'nginxIngress.controller.daemonset.useHostPort' "$use_host_port"
    replace_set_me "$1" 'nginxIngress.controller.service.enabled' "$service_enabled"
}

# Usage: set_nginx_config <config-file>
set_elasticsearch_config() {
    file=$1
    if [[ ! -f "${file}" ]]; then
        log_error "ERROR: invalid file - $file"
        exit 1
    fi

        case ${CK8S_CLOUD_PROVIDER} in
        safespring | citycloud | exoscale)
          use_regionendpoint=true
          ;;

        aws)
          use_regionendpoint=false
          ;;

    esac

    replace_set_me "$1" 'elasticsearch.useRegionEndpoint' "$use_regionendpoint"
    replace_set_me "$1" 'elasticsearch.snapshotRepository' "s3_${CK8S_CLOUD_PROVIDER}_7.x"
}

# Usage: set_harbor_config <config-file>
set_harbor_config() {
    file=$1
    if [[ ! -f "${file}" ]]; then
        log_error "ERROR: invalid file - $file"
        exit 1
    fi
    case ${CK8S_CLOUD_PROVIDER} in
        aws | exoscale | safespring)
          persistence_type=s3
          ;;

        citycloud)
          persistence_type=swift
          ;;

    esac
    replace_set_me "$1" 'harbor.persistence.type' "$persistence_type"
}

# Usage: generate_secrets <config-file>
generate_secrets() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in generates_secrets must be 1. #=[$#]"
        exit 1
    fi
    file=$1
    if [[ -f $file ]]; then
        sops_decrypt "$file"
        yq m -i "$file" "${config_defaults_path}/secrets/sc-secrets.yaml"
    else
        cat "${config_defaults_path}/secrets/sc-secrets.yaml" > "$file"
    fi
    yq m -i "$file" "${config_defaults_path}/secrets/wc-secrets.yaml"
    case ${CK8S_CLOUD_PROVIDER} in

        safespring | citycloud)
          cloud_file="${config_defaults_path}/secrets/citycloud.yaml"
          yq m -i "$file" "$cloud_file"
          ;;

    esac

    sops_encrypt "$file"
}


log_info "Initializing CK8S configuration with flavor: $CK8S_FLAVOR"


if [ -f "${sops_config}" ]; then
    log_info "SOPS config already exists: ${sops_config}"
    validate_sops_config
else
    generate_sops_config
fi

mkdir -p "${state_path}"

# TODO: Not a fan of this directory, we should probably have a separate script
#       for generating user configurations and not store it as a part of
#       the ck8s configuration.
mkdir -p "${CK8S_CONFIG_PATH}/user"
CK8S_VERSION=$(version_get)
export CK8S_VERSION

if [ -f "${config[config_file_sc]}" ]; then
    log_info "${config[config_file_sc]} already exists, merging with existing config"
fi
generate_base_sc_config "${config[config_file_sc]}"
set_storage_class "${config[config_file_sc]}"
set_nginx_config "${config[config_file_sc]}"
set_elasticsearch_config "${config[config_file_sc]}"
set_harbor_config "${config[config_file_sc]}"

if [ -f "${config[config_file_wc]}" ]; then
    log_info "${config[config_file_wc]} already exists, merging with existing config"
fi
generate_base_wc_config "${config[config_file_wc]}"
set_storage_class "${config[config_file_wc]}"
set_nginx_config "${config[config_file_wc]}"
set_elasticsearch_config "${config[config_file_wc]}"
set_harbor_config "${config[config_file_wc]}"

if [ -f "${secrets[secrets_file]}" ]; then
    log_info "${secrets[secrets_file]} already exists, merging with existing secrets"
fi
# TODO: Generate random passwords
generate_secrets "${secrets[secrets_file]}"


log_info "Config initialized"

log_info "Time to edit the following files:"
log_info "${config[config_file_sc]}"
log_info "${config[config_file_wc]}"
log_info "${secrets[secrets_file]}"
