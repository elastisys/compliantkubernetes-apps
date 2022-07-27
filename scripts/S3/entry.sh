#!/bin/bash

set -e

# Wrapper for manager.sh, reads the 'objectStorage' block from the configs, then
# creates the S3 buckets specified in 'objectStorage.buckets.*'.

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
CK8S_AUTO_APPROVE=${CK8S_AUTO_APPROVE:-"false"}

here="$(dirname "$(readlink -f "$0")")"

log_info() {
    echo -e "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_error() {
    echo -e "[\e[31mck8s\e[0m] ${*}" 1>&2
}

common_default=$(yq4 -o j '.objectStorage' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml")

# shellcheck disable=SC2016
sc_default=$(echo "${common_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"))
# shellcheck disable=SC2016
sc_config=$(echo "${sc_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage' "${CK8S_CONFIG_PATH}/common-config.yaml") <(yq4 -o j '.objectStorage' "${CK8S_CONFIG_PATH}/sc-config.yaml") | yq4 '{"objectStorage":.}' -)

# shellcheck disable=SC2016
wc_default=$(echo "${common_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage' "${CK8S_CONFIG_PATH}/defaults/wc-config.yaml" -j 'objectStorage'))
# shellcheck disable=SC2016
wc_config=$(echo "${wc_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage' "${CK8S_CONFIG_PATH}/common-config.yaml" -j 'objectStorage') <(yq4 -o j '.objectStorage' "${CK8S_CONFIG_PATH}/wc-config.yaml" -j 'objectStorage') |  yq4 '{"objectStorage":.}' -)

objectstorage_type_sc=$(echo "${sc_config}" | yq4 '.objectStorage.type' -)
objectstorage_type_wc=$(echo "${wc_config}" | yq4 '.objectStorage.type' -)

[ "$objectstorage_type_sc" != "s3" ] && log_info "S3 is not enabled in service cluster"
[ "$objectstorage_type_wc" != "s3" ] && log_info "S3 is not enabled in workload cluster"

if [ "$objectstorage_type_sc" != "s3" ] && [ "$objectstorage_type_wc" != "s3" ]; then
    log_error "S3 is not enabled in either cluster, aborting!"
    exit 1
fi

[ "$objectstorage_type_sc" = "s3" ] && buckets_sc=$(echo "${sc_config}" | yq4 '.objectStorage.buckets.*' -)
[ "$objectstorage_type_wc" = "s3" ] && buckets_wc=$(echo "${wc_config}" | yq4 '.objectStorage.buckets.*' -)

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
