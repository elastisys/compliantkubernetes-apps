#!/bin/bash

set -e

# Wrapper for manager.sh, reads config from ${CK8S_CONFIG_PATH}/{sc,wc}-config.yaml
# and creates the S3 buckets specified in 'objectStorage.buckets.*'.

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
CK8S_AUTO_APPROVE=${CK8S_AUTO_APPROVE:-"false"}

here="$(dirname "$(readlink -f "$0")")"

objectstorage_type_sc=$(yq r "${CK8S_CONFIG_PATH}/sc-config.yaml" 'objectStorage.type')
objectstorage_type_wc=$(yq r "${CK8S_CONFIG_PATH}/wc-config.yaml" 'objectStorage.type')

[ "$objectstorage_type_sc" != "s3" ] && echo "S3 is not enabled in service cluster" 1>&2
[ "$objectstorage_type_wc" != "s3" ] && echo "S3 is not enabled in workload cluster" 1>&2

if [ "$objectstorage_type_sc" != "s3" ] && [ "$objectstorage_type_wc" != "s3" ]; then
    echo "S3 is not enabled in either cluster, aborting!" 1>&2
    exit 1
fi

[ "$objectstorage_type_sc" = "s3" ] && buckets_sc=$(yq r "${CK8S_CONFIG_PATH}/sc-config.yaml" 'objectStorage.buckets.*')
[ "$objectstorage_type_wc" = "s3" ] && buckets_wc=$(yq r "${CK8S_CONFIG_PATH}/wc-config.yaml" 'objectStorage.buckets.*')

buckets=$( { echo "$buckets_sc"; echo "$buckets_wc"; } | sort | uniq | tr '\n' ' ')

function usage() {
    echo "Usage:" 1>&2
    echo "  $0 [--s3cfg config-path] create|delete" 1>&2
    exit 1
}

if [ "$1" = "--s3cfg" ]; then
    [ "$#" -ne 3 ] && echo "Invalid number of arguments" 1>&2 && usage
    action="$3"
    cmd="${here}/manager.sh $1 $2 --$3 $buckets"
else
    [ "$#" -ne 1 ] && echo "Invalid number of arguments" 1>&2 && usage
    action="$1"
    cmd="${here}/manager.sh --$1 $buckets"
fi

if [ "$action" = "delete" ] && ! ${CK8S_AUTO_APPROVE}; then
    echo -n -e "Are you sure you want to delete all buckets? (y/n): " 1>&2
    read -r reply
    if [[ "${reply}" == "n" ]]; then
        exit 1
    fi
fi

$cmd
