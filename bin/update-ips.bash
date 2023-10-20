#!/bin/bash

# This script checks the IPs that are setup for network policies and reports the diff
# If set to update the config, it will also update the config files.

# Usage: update-ips.bash <cluster> <action>
#   cluster: What cluster config to check for (sc, wc or both)
#   action: If the script should update the config or not (update or dry-run)

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

CHECK_CLUSTER="${1}" # sc, wc or both
DRY_RUN=true
if [[ "${2}" == "update" ]]; then
    DRY_RUN=false
fi
has_diff=0

# Compares a list IPs with the list of IPs in the yaml path and file specified and returns the diff return code.
# If DRY_RUN is set, it will output to stdout, otherwise it will just return the diff return code silently.
# Usage: diffIPs <yaml_path> <file> <IP 1> <IP ..>
diffIPs() {
    local yaml_path
    local file
    local IPS
    yaml_path="${1}"
    file="${2}"
    shift 2
    IPS=("$@")
    tmp_file=$(mktemp --suffix=.yaml)

    yq4 -n '. = []' > "${tmp_file}"
    for ip in "${IPS[@]}"; do
        yq4 -i '. |= . + ["'"${ip}"'/32"]' "${tmp_file}"
    done

    if $DRY_RUN; then
        out_file=/dev/stdout
    else
        out_file=/dev/null
    fi
    diff -U3 --color=always \
        --label "${file//${CK8S_CONFIG_PATH}\//}" <(yq4 -P "${yaml_path}"' // [] | sort_by(.)' "${file}") \
        --label expected <(yq4 -P '. | sort_by(.)' "${tmp_file}") > "${out_file}"
    DIFF_RETURN=$?
    rm "${tmp_file}"
    return ${DIFF_RETURN}
}

# Fetches the IPs from a specified address
# Usage: getDNSIPs <dns_record>
getDNSIPs() {
    local IPS
    mapfile -t IPS < <(dig +short "${1}" | grep '^[.0-9]*$')
    if [ ${#IPS[@]} -eq 0 ]; then
        log_error "No ips for ${1} was found"
        exit 1
    fi
    echo "${IPS[@]}"
}

# Usage: diffDNSIPs <dns_record> <yaml_path> <file>
diffDNSIPs() {
    local IPS
    read -r -a IPS <<< "$(getDNSIPs "${1}")"
    diffIPs "${2}" "${3}" "${IPS[@]}"
    return $?
}

# Updates the list from the file and yaml path specified with IPs fetched from the domain
# Usage: updateDNSIPs <dns_record> <yaml_path> <file>
updateDNSIPs() {
    read -r -a IPS <<< "$(getDNSIPs "${1}")"

    yq4 -i "${2}"' = []' "${3}"
    for ip in "${IPS[@]}"; do
        yq4 -i "${2}"' |= . + ["'"${ip}"'/32"]' "${3}"
    done
}

# Usage: updateIPs <yaml_path> <file> <IP 1> <IP ..>
updateIPs() {
    local yaml_path="${1}"
    local file="${2}"
    shift 2
    local IPS=("$@")

    yq4 -i "${yaml_path}"' = []' "${file}"
    for ip in "${IPS[@]}"; do
        yq4 -i "${yaml_path}"' |= . + ["'"${ip}"'/32"]' "${file}"
    done
}

# Fetches the Internal IP and calico tunnel ip of kubernetes nodes using the label selector.
# If label selector isn't specified, all nodes will be returned.
getKubectlIPs() {
    local IPS_internal
    local IPS_calico
    local IPS
    local label_argument=""
    if [[ "${2}" != "" ]]; then
        label_argument="-l ${2}"
    fi
    mapfile -t IPS_internal < <("${here}/ops.bash" kubectl "${1}" get node "${label_argument}" -ojsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    mapfile -t IPS_calico < <("${here}/ops.bash" kubectl "${1}" get node "${label_argument}" -ojsonpath='{.items[*].metadata.annotations.projectcalico\.org/IPv4IPIPTunnelAddr}')
    mapfile -t IPS_wireguard < <("${here}/ops.bash" kubectl "${1}" get node "${label_argument}" -ojsonpath='{.items[*].metadata.annotations.projectcalico\.org/IPv4WireguardInterfaceAddr}')
    read -r -a IPS <<< "${IPS_internal[*]} ${IPS_calico[*]} ${IPS_wireguard[*]}"
    if [ ${#IPS[@]} -eq 0 ]; then
        log_error "No ips for ${1} nodes with labels ${2} was found"
        exit 1
    fi
    echo "${IPS[@]}"
}

diffKubectlIPs() {
    local IPS
    read -r -a IPS <<< "$(getKubectlIPs "${1}" "${2}")"
    diffIPs "${3}" "${4}" "${IPS[@]}"
    return $?
}

# Updates the list from the file and yaml path specified with IPs fetched from the nodes
updateKubectlIPs() {
    local IPS
    read -r -a IPS <<< "$(getKubectlIPs "${1}" "${2}")"

    yq4 -i "${3}"' = []' "${4}"
    for ip in "${IPS[@]}"; do
        yq4 -i "${3}"' |= . + ["'"${ip}"'/32"]' "${4}"
    done
}

# Usage: checkIfDiffAndUpdateDNSIPs <dns_record> <yaml_path> <file>
checkIfDiffAndUpdateDNSIPs() {
    if ! diffDNSIPs "${1}" "${2}" "${3}"; then
        if ! $DRY_RUN; then
            updateDNSIPs "${1}" "${2}" "${3}"
        else
            log_warning "Diff found for ${2} in ${3//${CK8S_CONFIG_PATH}\//} (diff shows actions needed to be up to date)"
        fi
        has_diff=$(( has_diff + 1 ))
    fi
}

checkIfDiffAndUpdateKubectlIPs() {
    if ! diffKubectlIPs "${1}" "${2}" "${3}" "${4}"; then
        if ! $DRY_RUN; then
            updateKubectlIPs "${1}" "${2}" "${3}" "${4}"
        else
            log_warning "Diff found for ${3} in ${4//${CK8S_CONFIG_PATH}\//} (diff shows actions needed to be up to date)"
        fi
        has_diff=$(( has_diff + 1 ))
    fi
}

# checkIfDiffAndUpdateIPs <yaml_path> <file> <IP 1> <IP ..>
checkIfDiffAndUpdateIPs() {
    local yaml_path="${1}"
    local file="${2}"
    shift 2
    local IPS=("$@")

    if ! diffIPs "${yaml_path}" "${file}" "${IPS[@]}"; then
        if ! $DRY_RUN; then
            updateIPs "${yaml_path}" "${file}" "${IPS[@]}"
        else
            log_warning "Diff found for ${yaml_path} in ${file//${CK8S_CONFIG_PATH}\//} (diff shows actions needed to be up to date)"
        fi
        has_diff=$(( has_diff + 1 ))
    fi
}

# checkIfDiffAndUpdatePorts <yaml_path> <file_path> <port 1> <port ..>
checkIfDiffAndUpdatePorts() {
    yaml_path="${1}"
    file="${2}"
    shift 2

    ports="$(echo "[$(for port in "$@"; do echo "$port,"; done)]" | yq4 -oj)"

    if $DRY_RUN; then
        out=/dev/stdout
    else
        out=/dev/null
    fi

    portDiff() {
      diff -U3 --color=always \
          --label "${file//${CK8S_CONFIG_PATH}\//}" <(yq4 -P "$yaml_path"' // [] | sort_by(.)' "$file") \
          --label expected <(echo "$ports" | yq4 -P '. | sort_by(.)') > "$out"
    }

    if ! portDiff ; then
        if ! $DRY_RUN; then
            yq4 -i "$yaml_path = $ports" "$file"
        else
            log_warning "Diff found for $yaml_path in ${file//${CK8S_CONFIG_PATH}\//} (diff shows actions needed to be up to date)"
        fi
        has_diff=$(( has_diff + 1 ))
    fi
}

# yq_dig <cluster> <yaml_path> <default>
yq_dig() {
  for conf in "${config["override_$1"]}" "${config["override_common"]}" "${config["default_$1"]}" "${config["default_common"]}"; do
      ret=$(yq4 "$2" "$conf")

      if [[ "$ret" != "null" ]]; then
          echo "$ret"
          return
      fi
  done

  echo "$3"
}

# yq_dig_secrets <yaml_path> <default>
yq_dig_secrets() {
    ret=$(sops -d "${secrets["secrets_file"]}" | yq4 "$1")

    if [[ "$ret" != "null" ]]; then
        echo "$ret"
        return
    fi

  echo "$2"
}

get_swift_url() {
    local auth_url
    local os_token
    local swift_url
    local swift_region

    auth_url="$(yq_dig 'sc' '.objectStorage.swift.authUrl' '""')"

    if [ -n "$(yq_dig_secrets '.objectStorage.swift.username' "")" ]; then
        response=$(curl -i -s -H "Content-Type: application/json" -d '
        {
          "auth": {
            "identity": {
              "methods": ["password"],
              "password": {
                "user": {
                  "name": "'"$(yq_dig_secrets '.objectStorage.swift.username' '""')"'",
                  "domain": { "name": "'"$(yq_dig "sc" '.objectStorage.swift.domainName' '""')"'" },
                  "password": "'"$(yq_dig_secrets '.objectStorage.swift.password' '""')"'"
                }
              }
            },
            "scope": {
              "project": {
                "name": "'"$(yq_dig "sc" '.objectStorage.swift.projectName' '""')"'",
                "domain": { "name": "'"$(yq_dig "sc" '.objectStorage.swift.projectDomainName' '""')"'" }
              }
            }
          }
        }' "${auth_url}/auth/tokens")
    elif [ -n "$(yq_dig_secrets '.objectStorage.swift.applicationCredentialID' "")" ]; then
        response=$(curl -i -s -H "Content-Type: application/json" -d '
        {
          "auth": {
            "identity": {
              "methods": ["application_credential"],
              "application_credential": {
                "id": "'"$(yq_dig_secrets '.objectStorage.swift.applicationCredentialID' '""')"'",
                "secret": "'"$(yq_dig_secrets '.objectStorage.swift.applicationCredentialSecret' '""')"'"
              }
            }
          }
        }' "${auth_url}/auth/tokens")
    fi

    swift_region=$(yq_dig "sc" '.objectStorage.swift.region' '""')
    os_token=$(echo "$response" | grep -oP "x-subject-token:\s+\K\S+")
    swift_url=$(echo "$response" | tail -n +15 | jq -r '.[].catalog[] | select( .type == "object-store" and .name == "swift") | .endpoints[] | select(.interface == "public" and .region == "'"$swift_region"'") | .url')

    curl -i -s -X DELETE -H "X-Auth-Token: $os_token" -H "X-Subject-Token: $os_token" "${auth_url}/auth/tokens" > /dev/null

    echo "$swift_url"
}

if [ "${CHECK_CLUSTER}" == "both" ]; then
  DIG_CLUSTER="sc"
else
  DIG_CLUSTER="wc"
fi
S3_ENDPOINT="$(yq_dig "${DIG_CLUSTER}" '.objectStorage.s3.regionEndpoint' '""' | sed 's/https\?:\/\///' | sed 's/[:\/].*//')"
if [[ "${S3_ENDPOINT}" == "" ]]; then
    log_error "No S3 endpoint found, check your common-config.yaml (or ${DIG_CLUSTER}-config.yaml)"
    exit 1
fi
S3_PORT="$(yq_dig 'sc' '.objectStorage.s3.regionEndpoint' '""' | sed 's/https\?:\/\///' | sed 's/[A-Za-z.0-9-]*:\?//' | sed 's/\/.*//')"
if [ -z "$S3_PORT" ]; then
    S3_PORT="443"
fi

OPS_DOMAIN="$(yq_dig "${DIG_CLUSTER}" '.global.opsDomain' '""')"
if [[ "${OPS_DOMAIN}" == "" ]]; then
    log_error "No ops domain found, check your common-config.yaml (or ${DIG_CLUSTER}-config.yaml)"
    exit 1
fi

BASE_DOMAIN="$(yq_dig "${DIG_CLUSTER}" '.global.baseDomain' '""')"
if [[ "${BASE_DOMAIN}" == "" ]]; then
    log_error "No base domain found, check your common-config.yaml (or ${DIG_CLUSTER}-config.yaml)"
    exit 1
fi

## Add object storage ips to common config
checkIfDiffAndUpdateDNSIPs "${S3_ENDPOINT}" ".networkPolicies.global.objectStorage.ips" "${config["override_common"]}"
## Add object storage port to common config
checkIfDiffAndUpdatePorts ".networkPolicies.global.objectStorage.ports" "${config["override_common"]}" "$S3_PORT"

## Add sc ingress ips to common config
checkIfDiffAndUpdateDNSIPs "grafana.${OPS_DOMAIN}" ".networkPolicies.global.scIngress.ips" "${config["override_common"]}"

## Add wc ingress ips to common config
checkIfDiffAndUpdateDNSIPs "non-existing-subdomain.${BASE_DOMAIN}" ".networkPolicies.global.wcIngress.ips" "${config["override_common"]}"

## Add sc apiserver ips
if [[ "${CHECK_CLUSTER}" =~ ^(sc|both)$ ]]; then
    checkIfDiffAndUpdateKubectlIPs "sc" "node-role.kubernetes.io/control-plane=" ".networkPolicies.global.scApiserver.ips" "${config["override_sc"]}"
fi

## Add wc apiserver ips
if [[ "${CHECK_CLUSTER}" =~ ^(wc|both)$ ]]; then
    checkIfDiffAndUpdateKubectlIPs "wc" "node-role.kubernetes.io/control-plane=" ".networkPolicies.global.wcApiserver.ips" "${config["override_wc"]}"
fi

## Add sc nodes ips to sc config
if [[ "${CHECK_CLUSTER}" =~ ^(sc|both)$ ]]; then
    checkIfDiffAndUpdateKubectlIPs "sc" "" ".networkPolicies.global.scNodes.ips" "${config["override_sc"]}"
fi

## Add wc nodes ips to wc config
if [[ "${CHECK_CLUSTER}" =~ ^(wc|both)$ ]]; then
    checkIfDiffAndUpdateKubectlIPs "wc" "" ".networkPolicies.global.wcNodes.ips" "${config["override_wc"]}"
fi

## Add Swift to sc config
if [[ "${CHECK_CLUSTER}" =~ ^(sc|both)$ ]]; then
    check_harbor="$(yq_dig 'sc' '.harbor.persistence.type' 'false')"
    check_thanos="$(yq_dig 'sc' '.thanos.objectStorage.type' 'false')"
    sourceType=$(yq4 '.objectStorage.sync.buckets.[].sourceType'  "${config["override_sc"]}")
    sourceSwift=false
    for type in $sourceType; do
      if [ "$type" == "swift" ]; then
        sourceSwift=true
      fi
    done
    if [ "$check_harbor" == "swift" ] || [ "$check_thanos" == "swift" ] || [ "${sourceSwift}" == "true" ]; then
        os_auth_endpoint="$(yq_dig 'sc' '.objectStorage.swift.authUrl' '""' | sed 's/https\?:\/\///' | sed 's/[:\/].*//')"

        if [ -z "$os_auth_endpoint" ]; then
            log_error "No openstack auth endpoint found, check your sc-config.yaml"
            exit 1
        fi

        os_auth_port="$(yq_dig 'sc' '.objectStorage.swift.authUrl' '""' | sed 's/https\?:\/\///' | sed 's/[A-Za-z.0-9-]*:\?//' | sed 's/\/.*//')"

        if [ -z "$os_auth_port" ]; then
            os_auth_port="5000"
        fi

        object_storage_swift_ips=()
        object_storage_swift_ports=()

        # shellcheck disable=SC2207
        object_storage_swift_ips+=($(getDNSIPs "$os_auth_endpoint"))
        object_storage_swift_ports+=("$os_auth_port")

        swift_url=$(get_swift_url)
        swift_endpoint="$(echo "$swift_url" | sed 's/https\?:\/\///' | sed 's/[:\/].*//')"
        swift_port="$(echo "$swift_url" | sed 's/https\?:\/\///' | sed 's/[A-Za-z.0-9-]*:\?//' | sed 's/\/.*//')"

        if [ -z "$swift_port" ]; then
            swift_port="443"
        fi

        # shellcheck disable=SC2207
        object_storage_swift_ips+=($(getDNSIPs "$swift_endpoint"))
        object_storage_swift_ports+=("$swift_port")

        checkIfDiffAndUpdateIPs ".networkPolicies.global.objectStorageSwift.ips" "${config["override_sc"]}" "${object_storage_swift_ips[@]}"
        checkIfDiffAndUpdatePorts ".networkPolicies.global.objectStorageSwift.ports" "${config["override_sc"]}" "${object_storage_swift_ports[@]}"
    fi
fi

## Add destination object storage ips for rclone sync to sc config
if [ "$(yq_dig 'sc' '.objectStorage.sync.enabled' 'false')" == "true" ]; then
    if [ "$(yq_dig 'sc' '.networkPolicies.rcloneSync.enabled' 'false')" == "true" ]; then
        check_sync_default_buckets="$(yq_dig 'sc' '.objectStorage.sync.syncDefaultBuckets' 'false')"
        destinationSwift=false
        if [ "${check_sync_default_buckets}" == "true" ]; then
          check_harbor="$(yq_dig 'sc' '.harbor.persistence.type' 'false')"
          check_thanos="$(yq_dig 'sc' '.thanos.objectStorage.type' 'false')"
          if [ "$check_harbor" == "swift" ] || [ "$check_thanos" == "swift" ]; then
              destinationSwift=true
          fi
        fi
        destination=$(yq4 '.objectStorage.sync.buckets.[].destinationType' "${config["override_sc"]}")
        destinationS3=false
        for type in $destination; do
          if [ "$type" == "swift" ]; then
            destinationSwift=true
          elif [ "$type" == "s3" ]; then
            destinationS3=true
          fi
        done

        ifNull=""
        S3_ENDPOINT_DST="$(yq_dig 'sc' '.objectStorage.sync.s3.regionEndpoint' "" | sed 's/https\?:\/\///' | sed 's/[:\/].*//')"
        S3_PORT_DST="$(yq_dig 'sc' '.objectStorage.sync.s3.regionEndpoint' "" | sed 's/https\?:\/\///' | sed 's/[A-Za-z.0-9-]*:\?//' | sed 's/\/.*//')"

        SWIFT_ENDPOINT_DST="$(yq_dig 'sc' '.objectStorage.sync.swift.authUrl' "" | sed 's/https\?:\/\///' | sed 's/[:\/].*//')"
        SWIFT_PORT_DST="$(yq_dig 'sc' '.objectStorage.sync.swift.authUrl' "" | sed 's/https\?:\/\///' | sed 's/[A-Za-z.0-9-]*:\?//' | sed 's/\/.*//')"

        if { [ "$destinationS3" == "true" ] && [ "$destinationSwift" != "true" ]; } || { [ "$destinationS3" != "true" ] && [ "$destinationSwift" != "true" ] && [ "$(yq_dig 'sc' '.objectStorage.sync.destinationType' 's3')" == "s3" ]; }; then
            if [ -z "${S3_ENDPOINT_DST}" ]; then
                log_error "No destination S3 endpoint for rclone sync found, check your sc-config.yaml"
                exit 1
            fi
            if [ -z "${S3_PORT_DST}" ]; then
                S3_PORT_DST="443"
            fi
            checkIfDiffAndUpdateDNSIPs "${S3_ENDPOINT_DST}" ".networkPolicies.rcloneSync.destinationObjectStorageS3.ips" "${config["override_sc"]}"
            checkIfDiffAndUpdatePorts ".networkPolicies.rcloneSync.destinationObjectStorageS3.ports" "${config["override_sc"]}" "$S3_PORT_DST"
            if [ -z "${SWIFT_ENDPOINT_DST}" ] && [ -z "${SWIFT_PORT_DST}" ] && [ $DRY_RUN == "true" ]; then
                results_diff=$(diff -U0 --color=always <(yq4 -P 'sort_keys(.networkPolicies.rcloneSync.destinationObjectStorageSwift)' "${config["override_sc"]}") <(yq4 -P 'del(.networkPolicies.rcloneSync.destinationObjectStorageSwift)' "${config["override_sc"]}") --label "${config["override_sc"]//${CK8S_CONFIG_PATH}\//}" --label expected) || true
                if [ "${results_diff}" != "" ]; then
                    printf "${results_diff}"'%s\n'
                    log_warning "Diff found for .networkPolicies.rcloneSync.destinationObjectStorageSwift in ${config[override_sc]//${CK8S_CONFIG_PATH}\//} (diff shows actions needed to be up to date)"
                fi
            elif [ -z "${SWIFT_ENDPOINT_DST}" ] && [ -z "${SWIFT_PORT_DST}" ] && [ $DRY_RUN != "true" ]; then
                yq4 -i 'del(.networkPolicies.rcloneSync.destinationObjectStorageSwift)' "${config["override_sc"]}"
            else
                checkIfDiffAndUpdateDNSIPs "${SWIFT_ENDPOINT_DST}" ".networkPolicies.rcloneSync.destinationObjectStorageSwift.ips" "${config["override_sc"]}"
                checkIfDiffAndUpdatePorts ".networkPolicies.rcloneSync.destinationObjectStorageSwift.ports" "${config["override_sc"]}" "$SWIFT_PORT_DST"
            fi
            ifNull=true
        fi
        if { [ "$destinationSwift" == "true" ] && [ "$destinationS3" != "true" ]; } || { [ "$destinationS3" != "true" ] && [ "$destinationSwift" != "true" ] && [ "$(yq_dig 'sc' '.objectStorage.sync.desinationType' 'swift')" == "swift" ]; }; then
            if [ -z "${SWIFT_ENDPOINT_DST}" ]; then
                log_error "No destination Swift endpoint for rclone sync found, check your sc-config.yaml"
                exit 1
            fi
            if [ -z "${SWIFT_PORT_DST}" ]; then
                SWIFT_PORT_DST="443"
            fi

            if [ -z "${S3_ENDPOINT_DST}" ] && [ -z "${S3_PORT_DST}" ] && [ $DRY_RUN == "true" ]; then
                results_diff=$(diff -U0 --color=always <(yq4 -P 'sort_keys(.networkPolicies.rcloneSync.destinationObjectStorageS3)' "${config["override_sc"]}") <(yq4 -P 'del(.networkPolicies.rcloneSync.destinationObjectStorageS3)' "${config["override_sc"]}") --label "${config["override_sc"]//${CK8S_CONFIG_PATH}\//}" --label expected) || true
                if [ "${results_diff}" != "" ]; then
                    printf "${results_diff}"'%s\n'
                    log_warning "Diff found for .networkPolicies.rcloneSync.destinationObjectStorageS3 in ${config[override_sc]//${CK8S_CONFIG_PATH}\//} (diff shows actions needed to be up to date)"
                fi
            elif [ -z "${S3_ENDPOINT_DST}" ] && [ -z "${S3_PORT_DST}" ] && [ $DRY_RUN != "true" ]; then
                yq4 -i 'del(.networkPolicies.rcloneSync.destinationObjectStorageS3)' "${config["override_sc"]}"
            else
                checkIfDiffAndUpdateDNSIPs "${S3_ENDPOINT_DST}" ".networkPolicies.rcloneSync.destinationObjectStorageS3.ips" "${config["override_sc"]}"
                checkIfDiffAndUpdatePorts ".networkPolicies.rcloneSync.destinationObjectStorageS3.ports" "${config["override_sc"]}" "$S3_PORT_DST"
            fi

            checkIfDiffAndUpdateDNSIPs "${SWIFT_ENDPOINT_DST}" ".networkPolicies.rcloneSync.destinationObjectStorageSwift.ips" "${config["override_sc"]}"
            checkIfDiffAndUpdatePorts ".networkPolicies.rcloneSync.destinationObjectStorageSwift.ports" "${config["override_sc"]}" "$SWIFT_PORT_DST"
            ifNull=true
        fi
        if { [ "$destinationSwift" == "true" ] && [ "$destinationS3" == "true" ]; } || [ -z "$ifNull" ] && { [ "$(yq_dig 'sc' '.objectStorage.sync.destinationType' 'swift')" == "swift" ] || [ "$(yq_dig 'sc' '.objectStorage.sync.destinationType' 's3')" == "s3" ]; }; then
            if [ -z "${S3_ENDPOINT_DST}" ]; then
                log_error "No destination S3 endpoint for rclone sync found, check your sc-config.yaml"
                exit 1
            fi
            if [ -z "${SWIFT_ENDPOINT_DST}" ]; then
                log_error "No destination Swift endpoint for rclone sync found, check your sc-config.yaml"
                exit 1
            fi
            if [ -z "${S3_PORT_DST}" ]; then
                S3_PORT_DST="443"
            fi
            if [ -z "${SWIFT_PORT_DST}" ]; then
                SWIFT_PORT_DST="443"
            fi

            checkIfDiffAndUpdateDNSIPs "${S3_ENDPOINT_DST}" ".networkPolicies.rcloneSync.destinationObjectStorageS3.ips" "${config["override_sc"]}"
            checkIfDiffAndUpdatePorts ".networkPolicies.rcloneSync.destinationObjectStorageS3.ports" "${config["override_sc"]}" "$S3_PORT_DST"

            checkIfDiffAndUpdateDNSIPs "${SWIFT_ENDPOINT_DST}" ".networkPolicies.rcloneSync.destinationObjectStorageSwift.ips" "${config["override_sc"]}"
            checkIfDiffAndUpdatePorts ".networkPolicies.rcloneSync.destinationObjectStorageSwift.ports" "${config["override_sc"]}" "$SWIFT_PORT_DST"
        fi

        SECONDARY_ENDPOINT="$(yq_dig 'sc' '.objectStorage.sync.secondaryUrl' "" | sed 's/https\?:\/\///' | sed 's/[:\/].*//')"
        if [ -n "${SECONDARY_ENDPOINT}" ]; then
            SECONDARY_PORT="$(yq_dig 'sc' '.objectStorage.sync.secondaryUrl' "" | sed 's/https\?:\/\///' | sed 's/[A-Za-z.0-9-]*:\?//' | sed 's/\/.*//')"
            if [ -z "${SECONDARY_PORT}" ]; then
                SECONDARY_PORT="443"
            fi
            checkIfDiffAndUpdateDNSIPs "${SECONDARY_ENDPOINT}" ".networkPolicies.rcloneSync.secondaryUrl.ips" "${config["override_sc"]}"
            checkIfDiffAndUpdatePorts ".networkPolicies.rcloneSync.secondaryUrl.ports" "${config["override_sc"]}" "$SECONDARY_PORT"

        elif  [ -z "${SECONDARY_ENDPOINT}" ] && [ $DRY_RUN == "true" ]; then
            results_diff=$(diff -U0 --color=always <(yq4 -P 'sort_keys(.networkPolicies.rcloneSync.secondaryUrl)' "${config["override_sc"]}") <(yq4 -P 'del(.networkPolicies.rcloneSync.secondaryUrl)' "${config["override_sc"]}") --label "${config["override_sc"]//${CK8S_CONFIG_PATH}\//}" --label expected) || true
            if [ "${results_diff}" != "" ]; then
                printf "${results_diff}"'%s\n'
                log_warning "Diff found for .networkPolicies.rcloneSync.secondaryUrl in ${config[override_sc]//${CK8S_CONFIG_PATH}\//} (diff shows actions needed to be up to date)"
            fi
        elif [ -z "${SECONDARY_ENDPOINT}" ] && [ $DRY_RUN != "true" ]; then
            yq4 -i 'del(.networkPolicies.rcloneSync.secondaryUrl)' "${config["override_sc"]}"
        fi
    fi
fi

exit ${has_diff}
