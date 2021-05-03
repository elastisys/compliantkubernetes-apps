#!/bin/bash

set -e

# Wrapper for manager.sh, reads config from ${CK8S_CONFIG_PATH}/{sc,wc}-config.yaml
# and creates the S3 buckets specified in 'objectStorage.buckets.*'.

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
CK8S_AUTO_APPROVE=${CK8S_AUTO_APPROVE:-"false"}

here="$(dirname "$(readlink -f "$0")")"

log_info() {
    echo -e "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_error() {
    echo -e "[\e[31mck8s\e[0m] ${*}" 1>&2
}

objectstorage_type_sc=$(yq r "${CK8S_CONFIG_PATH}/sc-config.yaml" 'objectStorage.type')
objectstorage_type_wc=$(yq r "${CK8S_CONFIG_PATH}/wc-config.yaml" 'objectStorage.type')

[ "$objectstorage_type_sc" != "s3" ] && log_info "S3 is not enabled in service cluster"
[ "$objectstorage_type_wc" != "s3" ] && log_info "S3 is not enabled in workload cluster"

if [ "$objectstorage_type_sc" != "s3" ] && [ "$objectstorage_type_wc" != "s3" ]; then
    log_error "S3 is not enabled in either cluster, aborting!"
    exit 1
fi

[ "$objectstorage_type_sc" = "s3" ] && buckets_sc=$(yq r "${CK8S_CONFIG_PATH}/sc-config.yaml" 'objectStorage.buckets.*')
[ "$objectstorage_type_wc" = "s3" ] && buckets_wc=$(yq r "${CK8S_CONFIG_PATH}/wc-config.yaml" 'objectStorage.buckets.*')

buckets=$( { echo "$buckets_sc"; echo "$buckets_wc"; } | sort | uniq | tr '\n' ' ' | sed s'/.$//')

log_info "Operating on buckets: ${buckets// /', '}"

function usage() {
    log_error "Usage: $0 [--s3cfg config-path] create|delete"
    exit 1
}

if [ "$1" = "--s3cfg" ]; then
    [ "$#" -ne 3 ] && log_error "Invalid number of arguments" && usage
    action="$3"
    cmd="${here}/manager.sh $1 $2 --$3 $buckets"
    log_info "Using s3cmd config file: $2"
else
    [ "$#" -ne 1 ] && log_error "Invalid number of arguments" && usage
    action="$1"
    cmd="${here}/manager.sh --$1 $buckets"
    log_info "Using s3cmd config file: ~/.s3cfg"
fi

if [ "$action" = "delete" ] && ! ${CK8S_AUTO_APPROVE}; then
    echo -n -e "[\e[34mck8s\e[0m] Are you sure you want to delete all buckets? (y/n): " 1>&2
    read -r reply
    if [[ ! "$reply" =~ ^[yY]$ ]]; then
        exit 1
    fi
fi

log_info "Running: $cmd"

$cmd
