#!/usr/bin/env bash

set -euo pipefail

# Define the path to the JSON file relative to the script's location
CONTROL_NODE_ROLE_DEFINITION_FILE="./scripts/azure/control-node-role-definition.json"
WORKER_NODE_ROLE_DEFINITION_FILE="./scripts/azure/worker-node-role-definition.json"

readonly CREATE_ACTION="create"
readonly DELETE_ACTION="delete"

log_info() {
    echo -e "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_error() {
    echo -e "[\e[31mck8s\e[0m] ${*}" 1>&2
}

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

function create_control_node_custom_role() {
    local role_name="${CK8S_ENVIRONMENT_NAME}-control-node"
    local role_description="Custom control node role for managing specific Azure resources used by CCM etc"

    export role_name
    export role_description
    export SUBSCRIPTIONS_ID

    # Check if the custom role already exists
    log_info "Checking if custom role $role_name exists" >&2
    # shellcheck disable=SC2086
    # shellcheck disable=SC2155
    local custom_role_exists=$(az role definition list --query "[?roleName=='$role_name']" | jq -r '.[] | select(.roleName=="'$role_name'") | .roleName')

    if [[ -n $custom_role_exists ]]; then
        log_info "Custom role $role_name already exists, skipping creation" >&2
    else
        log_info "Custom role $role_name does not exist, creating now" >&2

        # Create the custom role
        envsubst < "$CONTROL_NODE_ROLE_DEFINITION_FILE" | az role definition create --role-definition @-
    fi
}

function create_worker_node_custom_role() {
    local role_name="${CK8S_ENVIRONMENT_NAME}-worker-node"
    local role_description="Custom worker node role for managing specific Azure resources used by CSI etc"

    export role_name
    export role_description
    export SUBSCRIPTIONS_ID

    # Check if the custom role already exists
    log_info "Checking if custom role $role_name exists" >&2
    # shellcheck disable=SC2086
    # shellcheck disable=SC2155
    local custom_role_exists=$(az role definition list --query "[?roleName=='$role_name']" | jq -r '.[] | select(.roleName=="'$role_name'") | .roleName')

    if [[ -n $custom_role_exists ]]; then
        log_info "Custom role $role_name already exists, skipping creation" >&2
    else
        log_info "Custom role $role_name does not exist, creating now" >&2

        # Create the custom role
        envsubst < "$WORKER_NODE_ROLE_DEFINITION_FILE" | az role definition create --role-definition @-
    fi
}

function delete_all() {
    # Delete the custom role
    az role definition delete --name "${CK8S_ENVIRONMENT_NAME}-control-node"
    az role definition delete --name "${CK8S_ENVIRONMENT_NAME}-worker-node"
}

if [[ "$ACTION" == "$CREATE_ACTION" ]]; then
    log_info "Creating custom role for control node" >&2
    create_control_node_custom_role
    create_worker_node_custom_role
elif [[ "$ACTION" == "$DELETE_ACTION" ]]; then
    log_info "deleting..." >&2
    delete_all
else
    log_error 'Unknown action - Aborting!' >&2 && usage
    exit 1
fi
