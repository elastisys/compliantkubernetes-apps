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
# shellcheck source=bin/common.bash
source "${here}/common.bash"

# Validate the cloud provider
if ! array_contains "${CK8S_CLOUD_PROVIDER}" "${ck8s_cloud_providers[@]}"; then
    log_error "ERROR: Unsupported cloud provider: ${CK8S_CLOUD_PROVIDER}"
    log_error "Supported providers: ${ck8s_cloud_providers[*]}"
    exit 1
fi

# Validate the flavor
if ! array_contains "${CK8S_FLAVOR}" "${ck8s_flavors[@]}"; then
    log_error "ERROR: Unsupported flavor: ${CK8S_FLAVOR}"
    log_error "Supported flavors: ${ck8s_flavors[*]}"
    exit 1
fi

generate_sops_config() {
    if [ -n "${CK8S_PGP_FP:-}" ]; then
        if ! gpg --list-keys | grep "${CK8S_PGP_FP}" > /dev/null 2>&1; then
            log_error "ERROR: Fingerprint does not exist in gpg keyring."
            log_error "CK8S_PGP_FP=${CK8S_PGP_FP}"
            exit 1
        fi
        fingerprint="${CK8S_PGP_FP}"
    elif [ -n "${CK8S_PGP_UID:-}" ]; then
        fingerprint=$(gpg --list-keys --with-colons "${CK8S_PGP_UID}" | \
                      awk -F: '$1 == "fpr" {print $10;}' | head -n 1 || \
                      echo "")
        if [ -z "${fingerprint}" ]; then
            log_error "ERROR: Unable to get fingerprint from gpg keyring using UID."
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
    append_trap "rm $tmpfile; chmod 444 $file" EXIT

    touch "$file"
    chmod 644 "$file"

    envsubst > "$tmpfile" < "${config_template_path}/config/sc-config.yaml"

    # Change this to use one flavor for cloud provider and one for "size" (e.g. dev, growth, enterprise)
    yq merge --inplace --overwrite "$tmpfile" "${config_template_path}/config/flavors/${CK8S_FLAVOR}-sc.yaml" --prettyPrint

    cat "$tmpfile" > "$file"
}

generate_base_wc_config() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in generate_base_wc_config must be 1. #=[$#]"
        exit 1
    fi
    file=$1
    tmpfile=$(mktemp)
    append_trap "rm $tmpfile; chmod 444 $file" EXIT

    touch "$file"
    chmod 644 "$file"

    envsubst > "$tmpfile" < "${config_template_path}/config/wc-config.yaml"

    # Change this to use one flavor for cloud provider and one for "size" (e.g. dev, growth, enterprise)
    yq merge --inplace --overwrite "$tmpfile" "${config_template_path}/config/flavors/${CK8S_FLAVOR}-wc.yaml" --prettyPrint

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
            storage_class=cinder-csi
            replace_set_me "${file}" "storageClasses.nfs.enabled" false
            replace_set_me "${file}" "storageClasses.cinder.enabled" false
            replace_set_me "${file}" "storageClasses.local.enabled" false
            replace_set_me "${file}" "storageClasses.ebs.enabled" false
            ;;

        exoscale)
            storage_class=rook-ceph-block
            replace_set_me "${file}" "storageClasses.nfs.enabled" false
            replace_set_me "${file}" "storageClasses.cinder.enabled" false
            replace_set_me "${file}" "storageClasses.local.enabled" false
            replace_set_me "${file}" "storageClasses.ebs.enabled" false
            ;;

        aws)
            storage_class=ebs-gp2
            replace_set_me "${file}" "storageClasses.nfs.enabled" false
            replace_set_me "${file}" "storageClasses.cinder.enabled" false
            replace_set_me "${file}" "storageClasses.local.enabled" false
            replace_set_me "${file}" "storageClasses.ebs.enabled" true
            ;;

        baremetal)
            storage_class=node-local
            replace_set_me "${file}" "storageClasses.nfs.enabled" false
            replace_set_me "${file}" "storageClasses.cinder.enabled" false
            replace_set_me "${file}" "storageClasses.local.enabled" true
            replace_set_me "${file}" "storageClasses.ebs.enabled" false
            ;;
    esac

    replace_set_me "${file}" "storageClasses.default" "${storage_class}"
}

# Usage: set_object_storage <config-file>
# baremetal support is experimental, keep as separate case until stable
set_object_storage() {
    file=$1
    if [[ ! -f "${file}" ]]; then
        log_error "ERROR: invalid file - $file"
        exit 1
    fi
    case ${CK8S_CLOUD_PROVIDER} in
        aws | exoscale)
            object_storage_type="s3"
            yq write --inplace "${file}" "objectStorage.s3.region" "set-me"
            yq write --inplace "${file}" "objectStorage.s3.regionEndpoint" "set-me"
            yq write --inplace "${file}" "objectStorage.s3.forcePathStyle" false
            ;;

        citycloud | safespring)
            object_storage_type="s3"
            yq write --inplace "${file}" "objectStorage.s3.region" "set-me"
            yq write --inplace "${file}" "objectStorage.s3.regionEndpoint" "set-me"
            yq write --inplace "${file}" "objectStorage.s3.forcePathStyle" true
            ;;

        baremetal)
            object_storage_type="none"
            ;;
    esac

    replace_set_me "${file}" "objectStorage.type" "${object_storage_type}"
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

    if [ "${service_enabled}" = "false" ]; then
        replace_set_me "${file}" "ingressNginx.controller.service.type" "set-me-if-ingressNginx.controller.service.enabled"
        replace_set_me "${file}" "ingressNginx.controller.service.annotations" "set-me-if-ingressNginx.controller.service.enabled"
    fi
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
        log_error "ERROR: invalid file - ${file}"
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

            yq write --inplace "${file}" "harbor.persistence.swift.identityApiVersion" 3
            yq write --inplace "${file}" "harbor.persistence.swift.authURL" "set-me"
            yq write --inplace "${file}" "harbor.persistence.swift.regionName" "set-me"
            yq write --inplace "${file}" "harbor.persistence.swift.projectDomainName" "set-me"
            yq write --inplace "${file}" "harbor.persistence.swift.userDomainName" "set-me"
            yq write --inplace "${file}" "harbor.persistence.swift.projectName" "set-me"
            yq write --inplace "${file}" "harbor.persistence.swift.projectID" "set-me"
            yq write --inplace "${file}" "harbor.persistence.swift.tenantName" "set-me"
            yq write --inplace "${file}" "harbor.persistence.swift.authVersion" 3
            ;;

        baremetal)
            persistence_type=objectStorage
            disable_redirect=false
            ;;
    esac

    replace_set_me "${file}" "harbor.persistence.type" "${persistence_type}"
    replace_set_me "${file}" "harbor.persistence.disableRedirect" "${disable_redirect}"
}

# Usage: update_config <default_config_file> <merged_config_file|override_config_file>
# Updates config to only contain custom values.
update_config() {
    default_config=$1
    override_config=$2

    if [ ! -f "${override_config}" ]; then
        touch "${override_config}"
    fi

    merged_config=$(mktemp)
    append_trap "rm $merged_config" EXIT
    new_config=$(mktemp)
    append_trap "rm $new_config" EXIT

    merge_config "${default_config}" "${override_config}" "${merged_config}"

    keys=$(yq compare "${default_config}" "${merged_config}" --tojson --printMode pv --stripComments -- '**' | \
           sed -rn 's/\+\{"(.+)":.*\}/\1/p' | sed -r 's/\[.+\].*//' | uniq || true)
    for key in ${keys}; do
        yq read "${merged_config}" "${key}" --tojson | \
        yq prefix - "${key}" --tojson | \
        yq merge "${new_config}" - --inplace --overwrite --arrays overwrite --prettyPrint
    done

    defaults=$(yq read "${default_config}" "**(.==set-me)" --tojson --printMode p | \
               sed -r 's/\.\[.*\].*//' | uniq)
    for default in ${defaults}; do
        key=$(yq read "${new_config}" "${default}" --tojson --printMode p)
        if [[ -z "${key}" ]]; then
            yq read "${default_config}" "${default}" --tojson | \
            yq prefix - "${default}" --tojson | \
            yq merge "${new_config}" - --inplace --overwrite --arrays overwrite --prettyPrint
        fi
    done

    preamble="# See the default configuration under \"defaults\" to see available and suggested options"
    echo "${preamble}" | cat - "${new_config}" > "${override_config}"
}

# Usage: update_secrets <config-file> <false|true>
update_secrets() {
    if [[ $# -ne 2 ]]; then
        log_error "ERROR: number of args in update_secrets must be 2. #=[$#]"
        exit 1
    fi
    file=$1
    generate_secrets=$2

    tmpfile=$(mktemp)
    append_trap "rm ${tmpfile}" EXIT

    yq merge "${config_template_path}/secrets/sc-secrets.yaml" "${config_template_path}/secrets/wc-secrets.yaml" > "${tmpfile}"

    if [[ -f $file ]]; then
        sops_decrypt "${file}"
        yq merge "${tmpfile}" "${file}" --inplace --prettyPrint --overwrite --arrays overwrite
    fi

    if [ "${generate_secrets}" = "true" ]; then
        generate_secrets "${tmpfile}"
    fi

    cat "${tmpfile}" > "${file}"
    sops_encrypt "${file}"
}

# Usage: generate_secrets <config-file>
generate_secrets() {
    if [[ $# -ne 1 ]]; then
        log_error "ERROR: number of args in generate_secrets must be 1. #=[$#]"
        exit 1
    fi
    tmpfile=$1

    # https://unix.stackexchange.com/questions/307994/compute-bcrypt-hash-from-command-line

    ES_ADM_PASS=$(pwgen -cns 20 1)
    ES_ADM_PASS_HASH=$(htpasswd -bnBC 10 "" "${ES_ADM_PASS}" | tr -d ':\n')

    ES_CONF_PASS=$(pwgen -cns 20 1)
    ES_CONF_PASS_HASH=$(htpasswd -bnBC 10 "" "${ES_CONF_PASS}" | tr -d ':\n')

    ES_KIBANA_PASS=$(pwgen -cns 20 1)
    ES_KIBANA_PASS_HASH=$(htpasswd -bnBC 10 "" "${ES_KIBANA_PASS}" | tr -d ':\n')

    DEX_STATIC_PASS=$(pwgen -cns 20 1)
    # shellcheck disable=SC2016
    DEX_STATIC_PASS_HASH=$(htpasswd -bnBC 10 "" "${DEX_STATIC_PASS}" | tr -d ':\n' | sed 's/$2y/$2a/')

    PROMETHEUS_WC_REMOTE_WRITE_PASS=$(pwgen -cns 20 1)

    yq write --inplace "${tmpfile}" 'grafana.password' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'grafana.clientSecret' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'grafana.opsClientSecret' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'harbor.password' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'harbor.databasePassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'harbor.clientSecret' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'harbor.xsrf' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'harbor.coreSecret' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'harbor.jobserviceSecret' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'harbor.registrySecret' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'influxDB.users.adminPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'influxDB.users.wcWriterPassword' "${PROMETHEUS_WC_REMOTE_WRITE_PASS}"
    yq write --inplace "${tmpfile}" 'influxDB.users.scWriterPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'elasticsearch.adminPassword' "${ES_ADM_PASS}"
    yq write --inplace "${tmpfile}" 'elasticsearch.adminHash' "${ES_ADM_PASS_HASH}"
    yq write --inplace "${tmpfile}" 'elasticsearch.clientSecret' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'elasticsearch.configurerPassword' "${ES_CONF_PASS}"
    yq write --inplace "${tmpfile}" 'elasticsearch.configurerHash' "${ES_CONF_PASS_HASH}"
    yq write --inplace "${tmpfile}" 'elasticsearch.kibanaPassword' "${ES_KIBANA_PASS}"
    yq write --inplace "${tmpfile}" 'elasticsearch.kibanaHash' "${ES_KIBANA_PASS_HASH}"
    yq write --inplace "${tmpfile}" 'elasticsearch.fluentdPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'elasticsearch.curatorPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'elasticsearch.snapshotterPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'elasticsearch.metricsExporterPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'elasticsearch.kibanaCookieEncKey' "$(pwgen -cns 32 1)"
    yq write --inplace "${tmpfile}" 'kubeapiMetricsPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'dex.staticPasswordNotHashed' "${DEX_STATIC_PASS}"
    yq write --inplace "${tmpfile}" 'dex.staticPassword' "${DEX_STATIC_PASS_HASH}"
    yq write --inplace "${tmpfile}" 'dex.kubeloginClientSecret' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'user.grafanaPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'user.alertmanagerPassword' "$(pwgen -cns 20 1)"
    yq write --inplace "${tmpfile}" 'prometheus.remoteWrite.password' "${PROMETHEUS_WC_REMOTE_WRITE_PASS}"
}

# Usage: backup_file <file>
backup_file() {
    if [ ! -f "$1" ]; then
        log_error "ERROR: args in backup_file must be a file. [$1]"
    fi

    if [ ! -d "${backup_config_path}" ]; then
        mkdir -p "${backup_config_path}"
    fi

    # Strip directroy and add timestamp
    backup_name=$(echo "$1" | sed "s/.*\///" | sed "s/.yaml/-$(date +%y%m%d%H%M%S).yaml/")

    cp "$1" "${backup_config_path}/${backup_name}"
}

log_info "Initializing CK8S configuration with flavor: $CK8S_FLAVOR"


if [ -f "${sops_config}" ]; then
    log_info "SOPS config already exists: ${sops_config}"
    validate_sops_config
else
    generate_sops_config
fi

mkdir -p "${state_path}"
mkdir -p "${default_config_path}"

# TODO: Not a fan of this directory, we should probably have a separate script
#       for generating user configurations and not store it as a part of
#       the ck8s configuration.
mkdir -p "${CK8S_CONFIG_PATH}/user"
CK8S_VERSION=$(version_get)
export CK8S_VERSION

if [ -f "${config[override_config_file_sc]}" ]; then
    backup_file "${config[override_config_file_sc]}"
    log_info "Updating sc config"
else
    log_info "Creating sc config"
fi

generate_base_sc_config  "${config[default_config_file_sc]}"
set_storage_class        "${config[default_config_file_sc]}"
set_object_storage       "${config[default_config_file_sc]}"
set_nginx_config         "${config[default_config_file_sc]}"
set_elasticsearch_config "${config[default_config_file_sc]}"
set_harbor_config        "${config[default_config_file_sc]}"

update_config "${config[default_config_file_sc]}" "${config[override_config_file_sc]}"

if [ -f "${config[override_config_file_wc]}" ]; then
    backup_file "${config[override_config_file_wc]}"
    log_info "Updating wc config"
else
    log_info "Creating wc config"
fi

generate_base_wc_config  "${config[default_config_file_wc]}"
set_storage_class        "${config[default_config_file_wc]}"
set_object_storage       "${config[default_config_file_wc]}"
set_nginx_config         "${config[default_config_file_wc]}"

update_config "${config[default_config_file_wc]}" "${config[override_config_file_wc]}"

gen_secrets=true
if [ -f "${secrets[secrets_file]}" ]; then
    backup_file "${secrets[secrets_file]}"
    if [ ${#} -gt 0 ] && [ "$1" = "--regenerate-secrets" ]; then
        log_info "Updating and regenerating secrets"
    else
        log_info "Updating secrets"
        gen_secrets=false
    fi
else
    log_info "Generating secrets"
fi

update_secrets "${secrets[secrets_file]}" "${gen_secrets}"

log_info "Config initialized"

log_info "Time to edit the following files:"
log_info "${config[override_config_file_sc]}"
log_info "${config[override_config_file_wc]}"
log_info "${secrets[secrets_file]}"
