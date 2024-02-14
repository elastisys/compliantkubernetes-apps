#!/bin/bash

set -e

readonly CREATE_ACTION="create"
readonly DELETE_ACTION="delete"

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

function create_resource_groupe() {

    echo "checking if resource groupe exists" >&2
    GROUP_EXISTS=$(az group list --query '[].name' | awk "/${CK8S_ENVIRONMENT_NAME}-storage-resource-groupe/")
    if [ "$GROUP_EXISTS" ]; then
        echo "resource groupe [${CK8S_ENVIRONMENT_NAME}-storage-resource-groupe] already exists" >&2
        echo "contnue using this group ? (y/n)" >&2
        # shellcheck disable=SC2162
        read -n 1 cmdinput
        case "$cmdinput" in
        y) return ;;
        n) exit 0 ;;
        esac
    else
        echo "resource groupe [${CK8S_ENVIRONMENT_NAME}-storage-resource-groupe] does not exist, creating it now" >&2
        az group create \
            --name "$CK8S_ENVIRONMENT_NAME"-storage-resource-groupe \
            --location swedencentral --only-show-errors
    fi

}

function create_storage_account() {

    echo "checking if storage account exists" >&2
    ACCOUNT_EXISTS=$(az storage account list --query '[].name' | awk "/${CK8S_ENVIRONMENT_NAME}storageaccount/")
    if [ "$ACCOUNT_EXISTS" ]; then
        echo "storage account [${CK8S_ENVIRONMENT_NAME}storageaccount] already exists" >&2
        echo "contnue using this account ? (y/n)" >&2
        # shellcheck disable=SC2162
        read -n 1 cmdinput
        case "$cmdinput" in
        y) return ;;
        n) exit 0 ;;
        esac
    else
        az storage account create \
            --name "$CK8S_ENVIRONMENT_NAME"storageaccount \
            --resource-group "$CK8S_ENVIRONMENT_NAME"-storage-resource-groupe \
            --location swedencentral \
            --sku Standard_RAGRS \
            --kind StorageV2 \
            --allow-blob-public-access false --only-show-errors
    fi
}

CONTAINERS=('audit' 'harbor' 'opensearch' 'sclogs' 'velero' 'thanos')

function create_containers() {

    for container in "${CONTAINERS[@]}"; do

        echo "checking status of container [${CK8S_ENVIRONMENT_NAME}-${container}]" >&2

        CONTAINER_EXISTS=$(echo "$CONTAINERS_LIST" | awk "/${CK8S_ENVIRONMENT_NAME}-${container}/")

        if [ "$CONTAINER_EXISTS" ]; then
            echo "container [${CK8S_ENVIRONMENT_NAME}-${container}] already exists, do nothing" >&2
        else
            echo "container [${CK8S_ENVIRONMENT_NAME}-${container}] does not exist, creating it now" >&2
            az storage container create \
                -n "$CK8S_ENVIRONMENT_NAME"-"$container" \
                --account-name "$CK8S_ENVIRONMENT_NAME"storageaccount --only-show-errors
        fi
    done
}

function delete_all() {
    az group delete --name "$CK8S_ENVIRONMENT_NAME"-storage-resource-groupe
}

if [[ "$ACTION" == "$CREATE_ACTION" ]]; then
    echo "Creating Resource Group" >&2
    create_resource_groupe

    echo "Creating Storage Account" >&2
    create_storage_account

    CONTAINERS_LIST=$(az storage container list --account-name "$CK8S_ENVIRONMENT_NAME"storageaccount --query '[].name' --only-show-errors)
    echo "Creating Storage Containers"
    create_containers "${CONTAINERS[@]}"
elif [[ "$ACTION" == "$DELETE_ACTION" ]]; then
    echo "deleting..." >&2
    delete_all
else
    echo 'Unknown action - Aborting!' >&2 && usage
    exit 1
fi
