#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
: "${AZURE_LOCATION:?Missing AZURE_LOCATION}"

readonly SET_ACTION="set"
readonly CREATE_ACTION="create"
readonly DELETE_ACTION="delete"
readonly LIST_HARBOR_BACKUPS="list-harbor-backups"

log_info() {
  echo -e "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_error() {
  echo -e "[\e[31mck8s\e[0m] ${*}" 1>&2
}

common_default=$(yq -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml")
# shellcheck disable=SC2016
common_config=$(echo "${common_default}" | yq eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/common-config.yaml") | yq '{"objectStorage":.}' -)

# shellcheck disable=SC2016
sc_default=$(echo "${common_default}" | yq eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"))
# shellcheck disable=SC2016
sc_config=$(echo "${sc_default}" | yq eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/common-config.yaml") <(yq -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/sc-config.yaml") | yq '{"objectStorage":.}' -)

# shellcheck disable=SC2016
wc_default=$(echo "${common_default}" | yq eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"))
# shellcheck disable=SC2016
wc_config=$(echo "${wc_default}" | yq eval-all --prettyPrint '. as $item ireduce ({}; . * $item )' - <(yq -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/common-config.yaml") <(yq -o j '.objectStorage // {}' "${CK8S_CONFIG_PATH}/wc-config.yaml") | yq '{"objectStorage":.}' -)

objectstorage_type_sc=$(echo "${sc_config}" | yq '.objectStorage.type' -)
objectstorage_type_wc=$(echo "${wc_config}" | yq '.objectStorage.type' -)

[ "$objectstorage_type_sc" != "azure" ] && log_info "Azure Storage is not enabled in service cluster"
[ "$objectstorage_type_wc" != "azure" ] && log_info "Azure Storage is not enabled in workload cluster"

if [ "$objectstorage_type_sc" != "azure" ] && [ "$objectstorage_type_wc" != "azure" ]; then
  log_error "Azure Storage is not enabled in either cluster, aborting!"
  exit 1
fi

[ "$objectstorage_type_sc" = "azure" ] && buckets_sc=$(echo "${sc_config}" | yq '.objectStorage.buckets.*' -)
[ "$objectstorage_type_wc" = "azure" ] && buckets_wc=$(echo "${wc_config}" | yq '.objectStorage.buckets.*' -)

RESOURCE_GROUP=$(echo "${common_config}" | yq '.objectStorage.azure.resourceGroup')
STORAGE_ACCOUNT=$(echo "${common_config}" | yq '.objectStorage.azure.storageAccountName')
CONTAINERS=$({
  echo "${buckets_sc:-}"
  echo "${buckets_wc:-}"
} | sort | uniq | tr '\n' ' ' | sed s'/.$//')

function usage() {
  echo "Usage:" 1>&2
  echo " $0 set" 1>&2
  echo " $0 create" 1>&2
  echo " $0 delete" 1>&2
}

if [ "${#}" -lt 1 ]; then
  usage
  exit 1
fi

case "$1" in
set)
  ACTION=$SET_ACTION
  ;;
create)
  ACTION=$CREATE_ACTION
  ;;
delete)
  ACTION=$DELETE_ACTION
  ;;
list-harbor-backups)
  ACTION=$LIST_HARBOR_BACKUPS
  ;;
esac
shift

if [[ "$ACTION" == "$CREATE_ACTION" || "$ACTION" == "$DELETE_ACTION" ]]; then
  log_info "Operating on containers: ${CONTAINERS// /', '}"
fi

function set_resource_group() {
  log_info "Getting existing resource groups" >&2
  EXISTING_GROUPS=$(az group list --query '[].name')
  if [[ "${EXISTING_GROUPS}" == "[]" ]]; then
    log_info "There are no existing resource groups."
    log_info "Current resource group in config is ${RESOURCE_GROUP}."
    log_info "Enter a new resource group name to override with, or press Enter to keep current: "
    read -r name
    if [[ -n "${name}" ]]; then
      yq -i '.objectStorage.azure.resourceGroup = "'"${name}"'"' "${CK8S_CONFIG_PATH}/common-config.yaml"
    fi
  else
    log_info "The following resource groups already exist:"
    log_info "${EXISTING_GROUPS}"
    log_info "Current resource group in config is ${RESOURCE_GROUP}."
    log_info "Enter a resource group name to override with, or press Enter to keep current: "
    read -r name
    if [[ -n "${name}" ]]; then
      yq -i '.objectStorage.azure.resourceGroup = "'"${name}"'"' "${CK8S_CONFIG_PATH}/common-config.yaml"
    fi
  fi
}

function set_storage_account() {
  log_info "Getting existing storage accounts" >&2
  EXISTING_ACCOUNTS=$(az storage account list --query '[].name')
  if [[ "${EXISTING_ACCOUNTS}" == "[]" ]]; then
    log_info "There are no existing storage accounts."
    log_info "Current storage account in config is ${STORAGE_ACCOUNT}."
    log_info "Enter a new storage account name to override with, or press Enter to keep current: "
    read -r name
    if [[ -n "${name}" ]]; then
      yq -i '.objectStorage.azure.storageAccountName = "'"${name}"'"' "${CK8S_CONFIG_PATH}/common-config.yaml"
    fi
  else
    log_info "The following storage accounts already exist:"
    log_info "${EXISTING_ACCOUNTS}"
    log_info "Current storage account in config is ${STORAGE_ACCOUNT}."
    log_info "Enter a storage account name to override with, or press Enter to keep current: "
    read -r name
    if [[ -n "${name}" ]]; then
      yq -i '.objectStorage.azure.storageAccountName = "'"${name}"'"' "${CK8S_CONFIG_PATH}/common-config.yaml"
    fi
  fi
}

function create_resource_group() {

  log_info "checking if resource group exists" >&2
  GROUP_EXISTS=$(az group list --query '[].name' | jq --arg group "${RESOURCE_GROUP}" '. | index($group)')
  if [ "$GROUP_EXISTS" != null ]; then
    log_info "resource group [${RESOURCE_GROUP}] already exists" >&2
    log_info "continue using this group ? (y/n)" >&2
    read -r -n 1 cmdinput
    case "$cmdinput" in
    y | Y) return ;;
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

function list_harbor_backups() {
  CONTAINER=$(echo "${sc_config}" | yq '.objectStorage.buckets.harbor')
  az storage blob list --account-name "${STORAGE_ACCOUNT}" --container-name "${CONTAINER}" --prefix "backups" -o table
}

if [[ "$ACTION" == "$SET_ACTION" ]]; then
  log_info "Setting Resource Group name" >&2
  set_resource_group

  log_info "Setting Storage Account name" >&2
  set_storage_account
elif [[ "$ACTION" == "$CREATE_ACTION" ]]; then
  log_info "Creating Resource Group" >&2
  create_resource_group

  log_info "Creating Storage Account" >&2
  create_storage_account

  log_info "Creating Storage Containers" >&2
  create_containers "${CONTAINERS}"
elif [[ "$ACTION" == "$DELETE_ACTION" ]]; then
  log_info "deleting..." >&2
  delete_all
elif [[ "$ACTION" == "$LIST_HARBOR_BACKUPS" ]]; then
  log_info "Listing harbor backups" >&2
  list_harbor_backups
else
  log_error 'Unknown action - Aborting!' >&2 && usage
  exit 1
fi
