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
    if [[ $(yq read "$1" "$2") == "set-me" ]]; then
       yq write --inplace "$1" "$2" "$3"
    fi

}

generate_base_sc_config() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in generate_base_sc_config must be 1. #=[$#]"
        exit 1
    fi
    file=$1
    tmpfile=$(mktemp)
    append_trap "rm $tmpfile" EXIT

    envsubst > "$tmpfile" < "${config_defaults_path}/config/sc-config.yaml"
    if [[ ${CK8S_CLOUD_PROVIDER} == "citycloud" ]]; then
        yq merge --inplace "$tmpfile" "${config_defaults_path}/config/citycloud.yaml"
    fi
    yq merge --inplace --overwrite "$tmpfile" "${config_defaults_path}/config/flavors/${CK8S_FLAVOR}-sc.yaml"
    if [[ -f $file ]]; then
        yq merge "$tmpfile" "$file" --inplace -a=overwrite --overwrite --prettyPrint
    fi

    cat "$tmpfile" > "$file"
}

generate_base_wc_config() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in generate_base_wc_config must be 1. #=[$#]"
        exit 1
    fi
    file=$1
    tmpfile=$(mktemp)
    append_trap "rm $tmpfile" EXIT

    envsubst > "$tmpfile" < "${config_defaults_path}/config/wc-config.yaml"
    yq merge --inplace --overwrite "$tmpfile" "${config_defaults_path}/config/flavors/${CK8S_FLAVOR}-wc.yaml"
    if [[ -f $file ]]; then
        yq merge "$tmpfile" "$file" --inplace -a=overwrite --overwrite --prettyPrint
    fi

    cat "$tmpfile" > "$file"
}

# Usage: set_storage_class <config-file>
# baremetal support is experimental, keep as separate case until stable
set_storage_class() {
    file=$1
    if [[ ! -f "${file}" ]]; then
        log_error "ERROR: invalid file - $file"
        exit 1
    fi
    case ${CK8S_CLOUD_PROVIDER} in
        safespring | citycloud)
          storage_class=cinder-storage

          [ "$(yq read "$file" 'storageClasses.nfs.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.nfs.enabled' false
          [ "$(yq read "$file" 'storageClasses.local.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.local.enabled' false
          [ "$(yq read "$file" 'storageClasses.ebs.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.ebs.enabled' false
          [ "$(yq read "$file" 'storageClasses.cinder.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.cinder.enabled' true
          ;;

        exoscale)
          storage_class=nfs-client

          [ "$(yq read "$file" 'storageClasses.nfs.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.nfs.enabled' true
          [ "$(yq read "$file" 'storageClasses.local.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.local.enabled' true
          [ "$(yq read "$file" 'storageClasses.ebs.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.ebs.enabled' false
          [ "$(yq read "$file" 'storageClasses.cinder.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.cinder.enabled' false
          ;;

        aws)
          storage_class=ebs-gp2

          [ "$(yq read "$file" 'storageClasses.nfs.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.nfs.enabled' false
          [ "$(yq read "$file" 'storageClasses.local.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.local.enabled' false
          [ "$(yq read "$file" 'storageClasses.ebs.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.ebs.enabled' true
          [ "$(yq read "$file" 'storageClasses.cinder.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.cinder.enabled' false
          ;;

        baremetal)
          storage_class=node-local

          [ "$(yq read "$file" 'storageClasses.nfs.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.nfs.enabled' false
          [ "$(yq read "$file" 'storageClasses.local.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.local.enabled' true
          [ "$(yq read "$file" 'storageClasses.ebs.enabled')" = "null" ] &&
            yq write --inplace "$file" 'storageClasses.ebs.enabled' false
          [ "$(yq read "$file" 'storageClasses.cinder.enabled')" = "null" ] &&
           yq write --inplace "$file" 'storageClasses.cinder.enabled' false
          ;;
    esac

    replace_set_me "$1" 'storageClasses.default' "$storage_class"
}

# Usage: set_nginx_config <config-file>
# baremetal support is experimental, keep as separate case until stable
set_nginx_config() {
    file=$1
    if [[ ! -f "${file}" ]]; then
        log_error "ERROR: invalid file - $file"
        exit 1
    fi
    case ${CK8S_CLOUD_PROVIDER} in
        citycloud | exoscale | safespring)
          use_proxy_protocol=false
          use_host_port=true
          service_enabled=false
          ;;

        aws)
          use_proxy_protocol=false
          use_host_port=false
          service_enabled=true
          service_type=LoadBalancer
          service_annotations='service.beta.kubernetes.io/aws-load-balancer-type: nlb'
          replace_set_me "$1" 'ingressNginx.controller.service.type' "$service_type"
          replace_set_me "$1" 'ingressNginx.controller.service.annotations' "$service_annotations"
          ;;

        baremetal)
          use_proxy_protocol=false
          use_host_port=true
          service_enabled=false
          ;;

    esac

    replace_set_me "$1" 'ingressNginx.controller.config.useProxyProtocol' "$use_proxy_protocol"
    replace_set_me "$1" 'ingressNginx.controller.useHostPort' "$use_host_port"
    replace_set_me "$1" 'ingressNginx.controller.service.enabled' "$service_enabled"
}

##
## TODO: rename to set_fluentd_config
##
# Usage: set_elasticsearch_config <config-file>
# baremetal support is experimental, keep as separate case until stable
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

        baremetal)
          use_regionendpoint=true
          ;;

    esac

    replace_set_me "$1" 'fluentd.forwarder.useRegionEndpoint' "$use_regionendpoint"
}

# Usage: set_harbor_config <config-file>
# baremetal support is experimental, keep as separate case until stable
set_harbor_config() {
    file=$1
    if [[ ! -f "${file}" ]]; then
        log_error "ERROR: invalid file - $file"
        exit 1
    fi
    case ${CK8S_CLOUD_PROVIDER} in
        aws | exoscale)
          persistence_type=objectStorage
          disable_redirect=false
          ;;

        safespring)
          persistence_type=objectStorage
          disable_redirect=true
          ;;

        citycloud)
          persistence_type=swift
          disable_redirect=true
          ;;

        baremetal)
          persistence_type=objectStorage
          disable_redirect=false
          ;;
    esac

    replace_set_me "$1" 'harbor.persistence.type' "$persistence_type"
    replace_set_me "$1" 'harbor.persistence.disableRedirect' "$disable_redirect"
}

# Usage: generate_secrets <config-file>
generate_secrets() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in generate_secrets must be 1. #=[$#]"
        exit 1
    fi
    file=$1
    tmpfile=$(mktemp)
    append_trap "rm $tmpfile" EXIT

    cat "${config_defaults_path}/secrets/sc-secrets.yaml" > "$tmpfile"
    yq merge --inplace "$tmpfile" "${config_defaults_path}/secrets/wc-secrets.yaml"
    case ${CK8S_CLOUD_PROVIDER} in
        citycloud)
          cloud_file="${config_defaults_path}/secrets/citycloud.yaml"
          yq merge --inplace "$tmpfile" "$cloud_file"
          ;;
    esac
    if [[ -f $file ]]; then
        sops_decrypt "$file"
        yq merge "$tmpfile" "$file" --inplace -a=overwrite --overwrite --prettyPrint
    fi

    cat "$tmpfile" > "$file"
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
generate_base_sc_config  "${config[config_file_sc]}"
set_storage_class        "${config[config_file_sc]}"
set_nginx_config         "${config[config_file_sc]}"
set_elasticsearch_config "${config[config_file_sc]}"
set_harbor_config        "${config[config_file_sc]}"

if [ -f "${config[config_file_wc]}" ]; then
    log_info "${config[config_file_wc]} already exists, merging with existing config"
fi
generate_base_wc_config  "${config[config_file_wc]}"
set_storage_class        "${config[config_file_wc]}"
set_nginx_config         "${config[config_file_wc]}"
set_elasticsearch_config "${config[config_file_wc]}"
set_harbor_config        "${config[config_file_wc]}"

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
