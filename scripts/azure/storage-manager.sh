#!/usr/bin/env bash

set -euo pipefail

readonly CREATE_ACTION="create"
readonly DELETE_ACTION="delete"

log_info() {
    echo -e "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_error() {
    echo -e "[\e[31mck8s\e[0m] ${*}" 1>&2
}

common_default=$(yq4 -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml")

# shellcheck disable=SC2016
sc_default=$(echo "${common_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"))
# shellcheck disable=SC2016
sc_config=$(echo "${sc_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/common-config.yaml") <(yq4 -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/sc-config.yaml") | yq4 '{"objectStorage":.}' -)

# shellcheck disable=SC2016
wc_default=$(echo "${common_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"))
# shellcheck disable=SC2016
wc_config=$(echo "${wc_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/common-config.yaml") <(yq4 -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/wc-config.yaml") |  yq4 '{"objectStorage":.}' -)

objectstorage_type_sc=$(echo "${sc_config}" | yq4 '.objectStorage.type' -)
objectstorage_type_wc=$(echo "${wc_config}" | yq4 '.objectStorage.type' -)

[ "$objectstorage_type_sc" != "azure" ] && log_info "Azure Storage is not enabled in service cluster"
[ "$objectstorage_type_wc" != "azure" ] && log_info "Azure Storage is not enabled in workload cluster"

if [ "$objectstorage_type_sc" != "azure" ] && [ "$objectstorage_type_wc" != "azure" ]; then
    log_error "Azure Storage is not enabled in either cluster, aborting!"
    exit 1
fi

[ "$objectstorage_type_sc" = "azure" ] && buckets_sc=$(echo "${sc_config}" | yq4 '.objectStorage.buckets.*' -)
[ "$objectstorage_type_wc" = "azure" ] && buckets_wc=$(echo "${wc_config}" | yq4 '.objectStorage.buckets.*' -)

CONTAINERS=$( { echo "$buckets_sc"; echo "$buckets_wc"; } | sort | uniq | tr '\n' ' ' | sed s'/.$//')

log_info "Operating on containers: ${CONTAINERS// /', '}"

function usage() {
    echo "Usage:" 1>&2
    echo " $0 create" 1>&2
    echo " $0 delete" 1>&2
}

case "$1" in
create)
    ACTION=$CREATE_ACTION
    ;;
delete)
    ACTION=$DELETE_ACTION
    ;;
esac
shift

function create_resource_group() {

    echo "checking if resource group exists" >&2
    GROUP_EXISTS=$(az group list --query '[].name' | awk "/${CK8S_ENVIRONMENT_NAME}-storage-resource-group/")
    if [ "$GROUP_EXISTS" ]; then
        echo "resource group [${CK8S_ENVIRONMENT_NAME}-storage-resource-group] already exists" >&2
        echo "continue using this group ? (y/n)" >&2
        read -r -n 1 cmdinput
        case "$cmdinput" in
        y|Y) return ;;
        *) exit 0 ;;
        esac
    else
        echo "resource group [${CK8S_ENVIRONMENT_NAME}-storage-resource-group] does not exist, creating it now" >&2
        az group create \
            --name "$CK8S_ENVIRONMENT_NAME"-storage-resource-group \
            --location "${AZURE_LOCATION}" --only-show-errors
    fi

}

function create_storage_account() {

    echo "checking if storage account exists" >&2
    ACCOUNT_EXISTS=$(az storage account list --query '[].name' | awk "/${CK8S_ENVIRONMENT_NAME}storageaccount/")
    if [ "$ACCOUNT_EXISTS" ]; then
        echo "storage account [${CK8S_ENVIRONMENT_NAME}storageaccount] already exists" >&2
        echo "contnue using this account ? (y/n)" >&2
        read -r -n 1 cmdinput
        case "$cmdinput" in
        y) return ;;
        n) exit 0 ;;
        esac
    else
        az storage account create \
            --name "$CK8S_ENVIRONMENT_NAME"storageaccount \
            --resource-group "$CK8S_ENVIRONMENT_NAME"-storage-resource-group \
            --location swedencentral \
            --sku Standard_RAGRS \
            --kind StorageV2 \
            --allow-blob-public-access false --only-show-errors
    fi
}

function create_containers() {

    CONTAINERS_LIST=$(az storage container list --account-name "$CK8S_ENVIRONMENT_NAME"storageaccount --query '[].name' --only-show-errors)

    # shellcheck disable=SC2068
    for container in ${CONTAINERS[@]}; do

        echo "checking status of container ${container}]" >&2

        CONTAINER_EXISTS=$(echo "$CONTAINERS_LIST" | awk "/${container}/")

        if [ "$CONTAINER_EXISTS" ]; then
            echo "container ${container}] already exists, do nothing" >&2
        else
            echo "container ${container}] does not exist, creating it now" >&2
            az storage container create \
                -n "$container" \
                --account-name "$CK8S_ENVIRONMENT_NAME"storageaccount --only-show-errors
        fi
    done
}

function delete_all() {
    az group delete --name "$CK8S_ENVIRONMENT_NAME"-storage-resource-group
}

if [[ "$ACTION" == "$CREATE_ACTION" ]]; then
    echo "Creating Resource Group" >&2
    create_resource_group

    echo "Creating Storage Account" >&2
    create_storage_account

    echo "Creating Storage Containers" >&2
    create_containers "${CONTAINERS}"
elif [[ "$ACTION" == "$DELETE_ACTION" ]]; then
    echo "deleting..." >&2
    delete_all
else
    echo 'Unknown action - Aborting!' >&2 && usage
    exit 1
fi
