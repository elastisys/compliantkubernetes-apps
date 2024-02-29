#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
: "${AZURE_LOCATION:?Missing AZURE_LOCATION}"

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
common_config=$(echo "${common_default}" | yq4 eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq4 -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/common-config.yaml") | yq4 '{"objectStorage":.}' -)

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

RESOURCE_GROUP=$(echo "${common_config}" | yq4 '.objectStorage.azure.resourceGroup')
STORAGE_ACCOUNT=$(echo "${common_config}" | yq4 '.objectStorage.azure.storageAccountName')
CONTAINERS=$( { echo "${buckets_sc:-}"; echo "${buckets_wc:-}"; } | sort | uniq | tr '\n' ' ' | sed s'/.$//')

log_info "Operating on containers: ${CONTAINERS// /', '}"

function usage() {
    echo "Usage:" 1>&2
    echo " $0 create" 1>&2
    echo " $0 delete" 1>&2
}

if [ "${#}" -lt 1 ]; then
  usage
  exit 1
fi

case "$1" in
create)
    ACTION=$CREATE_ACTION
    ;;
delete)
    ACTION=$DELETE_ACTION
    ;;
esac
shift


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

function create_resource_group() {

    log_info "checking if resource group exists" >&2
    GROUP_EXISTS=$(az group list --query '[].name' | jq --arg group "${RESOURCE_GROUP}" '. | index($group)')
    if [ "$GROUP_EXISTS" != null ]; then
        log_info "resource group [${RESOURCE_GROUP}] already exists" >&2
        log_info "continue using this group ? (y/n)" >&2
        read -r -n 1 cmdinput
        case "$cmdinput" in
        y|Y) return ;;
        *) exit 0 ;;
        esac
    else
        log_info "resource group [${RESOURCE_GROUP}] does not exist, creating it now" >&2
        az group create \
            --name "${RESOURCE_GROUP}" \
            --location "${AZURE_LOCATION}" --only-show-errors
    fi
}

function create_storage_account() {

    log_info "checking storage account availability" >&2
    out=$(az storage account check-name --only-show-errors --name "${STORAGE_ACCOUNT}")
    ACCOUNT_AVAILABLE=$(echo "$out" | jq -r .nameAvailable)
    REASON=$(echo "$out" | jq -r .reason)
    case $ACCOUNT_AVAILABLE in
        false)
            if [ "$REASON" == "AccountNameInvalid" ]; then
                log_info "Account name invalid, must be only contain numbers and lowercase letters"
                exit 0
            elif [ "$REASON" == "AlreadyExists" ]; then
                log_info "storage account [${STORAGE_ACCOUNT}] already exists" >&2
                log_info "contnue using this account ? (y/n)" >&2
                read -r -n 1 cmdinput
                case "$cmdinput" in
                y) return ;;
                n) exit 0 ;;
                esac
            fi
            ;;
        true)
            log_info "creating storage account ${STORAGE_ACCOUNT}"
            az storage account create \
            --name "$STORAGE_ACCOUNT" \
            --resource-group "${RESOURCE_GROUP}" \
            --location swedencentral \
            --sku Standard_RAGRS \
            --kind StorageV2 \
            --allow-blob-public-access false --only-show-errors
            ;;
    esac
}

function create_containers() {

    CONTAINERS_LIST=$(az storage container list --account-name "$STORAGE_ACCOUNT" --query '[].name' --only-show-errors)
    # shellcheck disable=SC2068
    for container in ${CONTAINERS[@]}; do
        log_info "checking status of container ${container}" >&2
        CONTAINER_EXISTS=$(echo "$CONTAINERS_LIST" | jq --arg container "${container}" '. | index($container)')
        if [ "$CONTAINER_EXISTS" != null ]; then
            log_info "container ${container} already exists, do nothing" >&2
        else
            log_info "container ${container} does not exist, creating it now" >&2
            az storage container create \
                -n "$container" \
                --account-name "$STORAGE_ACCOUNT" --only-show-errors
        fi
    done
}

function delete_all() {
    az group delete --name "${RESOURCE_GROUP}"
}

if [[ "$ACTION" == "$CREATE_ACTION" ]]; then
    log_info "Creating Resource Group" >&2
    create_resource_group

    log_info "Creating Storage Account" >&2
    create_storage_account

    log_info "Creating Storage Containers" >&2
    create_containers "${CONTAINERS}"
elif [[ "$ACTION" == "$DELETE_ACTION" ]]; then
    log_info "deleting..." >&2
    delete_all
else
    log_error 'Unknown action - Aborting!' >&2 && usage
    exit 1
fi