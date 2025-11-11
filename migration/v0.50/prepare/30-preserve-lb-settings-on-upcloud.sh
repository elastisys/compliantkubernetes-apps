#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# Extract the cloud provider name from the sc-config.yaml.
cloud_provider=$(yq_dig sc .global.ck8sCloudProvider)

if [[ "${cloud_provider}" == "upcloud" ]]; then
    log_info "Cloud provider is ${cloud_provider}. Moving current LB useHostPort and service.enabled configuration to override"
    
    # List of paths to migrate
    PATHS=(
        .ingressNginx.controller.service.enabled
        .ingressNginx.controller.useHostPort
    )

    # --- Service Cluster (SC) / Both Cluster Logic ---
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
        log_info "Applying migration for Service Cluster (SC)"
        
        for PATH_KEY in "${PATHS[@]}"; do
            # 1. CRITICAL FIX: Capture the output, which will be empty if 'select(. != null)' fails.
            VALUE_TO_MIGRATE="$(yq_merge "${CK8S_CONFIG_PATH}/defaults/common-config.yaml" "${CK8S_CONFIG_PATH}/common-config.yaml" | yq -r "${PATH_KEY} | select(. != null)")"
            
            # 2. CRITICAL FIX: Only run yq_add if the output is NOT empty.
            if [[ -n "${VALUE_TO_MIGRATE}" ]]; then
                # The value is found and clean. Pass it to yq_add.
                log_info "  -> Migrating ${PATH_KEY} with value ${VALUE_TO_MIGRATE} to sc-config.yaml"
                yq_add sc "${PATH_KEY}" "${VALUE_TO_MIGRATE}"
            else
                log_info "  -> Skipping ${PATH_KEY}: Value not found in common configs."
            fi
        done
    fi

    # --- Workload Cluster (WC) / Both Cluster Logic ---
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
        log_info "Applying migration for Workload Cluster (WC)"
        
        for PATH_KEY in "${PATHS[@]}"; do
            # 1. CRITICAL FIX: Capture the output, which will be empty if 'select(. != null)' fails.
            VALUE_TO_MIGRATE="$(yq_merge "${CK8S_CONFIG_PATH}/defaults/common-config.yaml" "${CK8S_CONFIG_PATH}/common-config.yaml" | yq -r "${PATH_KEY} | select(. != null)")"
            
            # 2. CRITICAL FIX: Only run yq_add if the output is NOT empty.
            if [[ -n "${VALUE_TO_MIGRATE}" ]]; then
                # The value is found and clean. Pass it to yq_add.
                log_info "  -> Migrating ${PATH_KEY} with value ${VALUE_TO_MIGRATE} to wc-config.yaml"
                yq_add wc "${PATH_KEY}" "${VALUE_TO_MIGRATE}"
            else
                log_info "  -> Skipping ${PATH_KEY}: Value not found in common configs."
            fi
        done
    fi

else
    log_info "Cloud provider is ${cloud_provider}. Skipping current LB useHostPort and service.enabled configuration migration to override config"
fi
