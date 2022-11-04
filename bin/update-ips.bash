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
getDNSIPs() {
    local IPS
    mapfile -t IPS < <(dig +short "${1}" | grep '^[.0-9]*$')
    if [ ${#IPS[@]} -eq 0 ]; then
        log_error "No ips for ${1} was found"
        exit 1
    fi
    echo "${IPS[@]}"
}

diffDNSIPs() {
    local IPS
    read -r -a IPS <<< "$(getDNSIPs "${1}")"
    diffIPs "${2}" "${3}" "${IPS[@]}"
    return $?
}

# Updates the list from the file and yaml path specified with IPs fetched from the domain
updateDNSIPs() {
    read -r -a IPS <<< "$(getDNSIPs "${1}")"

    yq4 -i "${2}"' = []' "${3}"
    for ip in "${IPS[@]}"; do
        yq4 -i "${2}"' |= . + ["'"${ip}"'/32"]' "${3}"
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
    read -r -a IPS <<< "${IPS_internal[*]} ${IPS_calico[*]}"
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

# checkIfDiffAndUpdatePorts <filepath> <yamlpath> <ports>...
checkIfDiffAndUpdatePorts() {
    filepath="$1"
    yamlpath="$2"
    shift 2

    ports="$(echo "[$(for port in "$@"; do echo "$port,"; done)]" | yq4 -oj)"

    if $DRY_RUN; then
        out=/dev/stdout
    else
        out=/dev/null
    fi

    portDiff() {
      diff -U3 --color=always \
          --label "${filepath//${CK8S_CONFIG_PATH}\//}" <(yq4 -P "$yamlpath"' // [] | sort_by(.)' "$filepath") \
          --label expected <(echo "$ports" | yq4 -P '. | sort_by(.)') > "$out"
    }

    if ! portDiff ; then
        if ! $DRY_RUN; then
            yq4 -i "$yamlpath = $ports" "$filepath"
        else
            log_warning "Diff found for $yamlpath in ${filepath//${CK8S_CONFIG_PATH}\//} (diff shows actions needed to be up to date)"
        fi
        has_diff=$(( has_diff + 1 ))
    fi
}

# yq_dig <cluster> <node> <default>
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
checkIfDiffAndUpdatePorts "${config["override_common"]}" ".networkPolicies.global.objectStorage.ports" "$S3_PORT"

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
    CHECK="$(yq_dig 'sc' '.harbor.persistence.type == "swift" or .thanos.objectStorage.type == "swift"' 'false')"
    if [ "$CHECK" == "true" ]; then
        SWIFT_ENDPOINT="$(yq_dig 'sc' '.objectStorage.swift.authUrl' '""' | sed 's/https\?:\/\///' | sed 's/[:\/].*//')"
        if [ -z "$SWIFT_ENDPOINT" ]; then
            log_error "No Swift endpoint found, check your sc-config.yaml"
            exit 1
        fi
        SWIFT_PORT="$(yq_dig 'sc' '.objectStorage.swift.authUrl' '""' | sed 's/https\?:\/\///' | sed 's/[A-Za-z.0-9-]*:\?//' | sed 's/\/.*//')"
        if [ -z "$SWIFT_PORT" ]; then
            SWIFT_PORT="443"
        fi

        checkIfDiffAndUpdateDNSIPs "${SWIFT_ENDPOINT}" ".networkPolicies.global.objectStorageSwift.ips" "${config["override_sc"]}"

        checkIfDiffAndUpdatePorts "${config["override_sc"]}" ".networkPolicies.global.objectStorageSwift.ports" "$SWIFT_PORT"
    fi
fi

## Add destination object storage ips for rclone sync to sc config
if [ "$(yq_dig 'sc' '.objectStorage.sync.enabled' 'false')" == "true" ]; then
    if [ "$(yq_dig 'sc' '.networkPolicies.rcloneSync.enabled' 'false')" == "true" ]; then

        S3_ENDPOINT_DST="$(yq_dig 'sc' '.objectStorage.sync.s3.regionEndpoint' '""' | sed 's/https\?:\/\///')"
        if [[ "${S3_ENDPOINT_DST}" == "" ]]; then
            log_error "No destination S3 endpoint for rclone sync found, check your sc-config.yaml"
            exit 1
        fi

        checkIfDiffAndUpdateDNSIPs "${S3_ENDPOINT_DST}" ".networkPolicies.rcloneSync.destinationObjectStorage.ips" "${config["override_sc"]}"
    fi
fi

exit ${has_diff}
