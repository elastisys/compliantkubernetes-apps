#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

cluster="${1}"
namespace="${2:-}"

file="${CK8S_CONFIG_PATH}/diagnostics-${cluster}-$(date +%y%m%d%H%M%S).log"
touch "${file}"

if [ -z "${CK8S_PGP_FP:-}" ]; then
    fingerprints=$(yq4 '.creation_rules[].pgp' "${sops_config}")

    log_warning "Notice for self-managed customers:"
    echo -e "\tEncrypting using the fingerprints: $fingerprints." 1>&2
    echo -e "\tIf you want to send diagnostic data to Elastisys, make sure to do:\n" 1>&2

    echo -e "\tCK8S_PGP_FP=<fingerprint provided during onboarding> ./bin/ck8s diagnostics [sc|wc]\n" 1>&2

    echo -e "\tIf in doubt, contact support@elastisys.com." 1>&2

    log_warning_no_newline "Do you want to continue anyway? (y/N): "
    read -r reply
    if [[ ! "${reply}" =~ ^[yY]$ ]]; then
        exit 1
    fi
fi

sops_encrypt_file() {
    if [ -z "${CK8S_PGP_FP:-}" ]; then
        sops_encrypt "${file}"
        return
    fi

    log_info "Encrypting ${file}"

    sops --pgp "${CK8S_PGP_FP}" -e -i "${file}"
}

run_diagnostics() {
    # -- ck8s --
    echo "Fetching CK8S software versions"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    if [ -d "${CK8S_CONFIG_PATH}/capi" ]; then
        # shellcheck disable=SC2002
        capi_version=$(cat "${CK8S_CONFIG_PATH}"/capi/defaults/values.yaml | yq4 '.clusterApiVersion')
        echo "CAPI version: ${capi_version}"
    elif [ -d "${CK8S_CONFIG_PATH}/sc-config" ]; then
        # shellcheck disable=SC2002
        kubespray_version=$(cat "${CK8S_CONFIG_PATH}"/sc-config/group_vars/all/ck8s-kubespray-general.yaml | yq4 '.ck8sKubesprayVersion')
        echo "Kubespray version: ${kubespray_version}"
    else
        echo "Can't find config directory"
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    # shellcheck disable=SC2002
    apps_version=$(cat "${CK8S_CONFIG_PATH}"/defaults/common-config.yaml | yq4 '.global.ck8sVersion')
    echo "Apps version: ${apps_version}"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    # -- Nodes --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Fetching Nodes that are NotReady (<node>)"
    nodes=$("${here}/ops.bash" kubectl "${cluster}" get nodes -o=yaml | yq4 '.items[] | select(.status.conditions[] | select(.type == "Ready" and .status != "True")) | .metadata.name' | tr '\n' ' ')
    if [ -z "${nodes}" ]; then
        echo -e "All Nodes are ready"
    else
        printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
        echo "${nodes}" | xargs "${here}/ops.bash" kubectl "${cluster}" get nodes -o wide
        printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
        echo -e "\nDescribing Nodes"
        echo "${nodes}" | xargs "${here}/ops.bash" kubectl "${cluster}" describe nodes
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    # -- DS and Deployments --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo -e "\nFetching Deployments without desired number of ready pods (<deployment>)"
    deployments=$("${here}"/ops.bash kubectl "${cluster}" get deployments -A -o=yaml | yq4 '.items[] | select(.status.conditions[] | select((.type == "Progressing" and .status != "True") or (.type == "Available" and .status != "True")))')
    if [ -z "${deployments}" ]; then
        echo -e "All Deployments are ready"
    else
        echo "${deployments}"
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    echo -e "\nFetching DaemonSets without desired number of ready pods (<daemonset>)"
    daemonsets=$("${here}"/ops.bash kubectl "${cluster}" get daemonsets -A -o=yaml | yq4 '.items[] | select(.status.numberMisscheduled != 0)')
    if [ -z "${daemonsets}" ]; then
        echo -e "All daemonsets are ready"
    else
        echo "${daemonsets}"
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    echo -e "\nFetching StatefulSets without desired number of ready pods (<statefulset>)"
    statefulsets=$("${here}"/ops.bash kubectl "${cluster}" get statefulsets -A -o=yaml | yq4 '.items[] | select(.status.collisionCount != 0 and .status.readyReplicas != .status.updatedReplicas and .status.replicas != .status.readyReplicas)')
    if [ -z "${statefulsets}" ]; then
        echo -e "All statefulsets are ready"
    else
        echo "${statefulsets}"
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Pods --
    echo -e "\nFetching Pods that are NotReady (<pod>)"
    pods=$("${here}/ops.bash" kubectl "${cluster}" get pod -A -o=yaml | yq4 '.items[] | select(.status.conditions[] | select(.type == "Ready" and .status != "True" and .reason != "PodCompleted")) | [{"name": .metadata.name, "namespace": .metadata.namespace}]')
    readarray pod_arr < <(echo "$pods" | yq4 e -o=j -I=0 '.[]')

    if [ "${pods}" == '[]' ]; then
        echo -e "All pods are ready"
    else
        for pod in "${pod_arr[@]}"; do
            pod_name=$(echo "$pod" | jq -r '.name')
            namespace=$(echo "$pod" | jq -r '.namespace')

            echo -e "\nDescribing pod <${pod_name}>"
            "${here}/ops.bash" kubectl "${cluster}" describe pod "${pod_name}" -n "${namespace}"

            echo -e "\nGetting logs from pod: <${pod_name}>"
            logs=$("${here}/ops.bash" kubectl "${cluster}" logs "${pod_name}" -n "${namespace}" --tail 20 || true)
            status="$?"
            if [ "${status}" -eq 0 ]; then
                echo "${logs}"
            fi

            echo -e "\nGetting previous logs from pod: <${pod_name}>"
            logs_prev=$("${here}/ops.bash" kubectl "${cluster}" logs -p "${pod_name}" -n "${namespace}" --tail 20 || true)
            status="$?"
            if [ "${status}" -eq 0 ]; then
                echo "${logs_prev}"
            fi
        done
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Top --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo -e "\nFetching cluster resource usage <top>"
    "${here}/ops.bash" kubectl "${cluster}" top nodes
    "${here}/ops.bash" kubectl "${cluster}" top pods -A
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Helm --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo -e "\nFetching Helm releases that are not deployed (<helm>)"
    helm=$("${here}"/ops.bash helm wc list -A --all -o yaml | yq4 '.[] | select(.status != "deployed")')
    if [ -z "${helm}" ]; then
        echo -e "All charts are deployed"
    else
        echo "${helm}"
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Cert --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo -e "\nFetching cert-manager resources (<cert>)"
    "${here}/ops.bash" kubectl "${cluster}" get clusterissuers,issuers,certificates,orders,challenges --all-namespaces -o wide

    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo -e "\nDescribing failed Challenges (<challenge>)"
    challenges=$("${here}/ops.bash" kubectl "${cluster}" get challenge -A -o=yaml | yq4 '.items[] | select(.status.state != "valid") | [{"name": .metadata.name, "namespace": .metadata.namespace}]')
    readarray challenge_arr < <(echo "$challenges" | yq4 e -o=j -I=0 '.[]')
    if [ "${challenges}" == '[]' ]; then
        echo -e "All challenges are valid"
    else
        for challenge in "${challenge_arr[@]}"; do
            challenge_name=$(echo "$challenge" | jq -r '.name')
            namespace=$(echo "$challenge" | jq -r '.namespace')
            "${here}/ops.bash" kubectl "${cluster}" describe challenge "${challenge_name}" -n "${namespace}"
        done
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Events --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo -e "\nFetching all Events (<event>)"
    "${here}/ops.bash" kubectl "${cluster}" get events -A --sort-by=.metadata.creationTimestamp
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # # -- Test --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    "${here}/ck8s" test "${cluster}"
}

run_diagnostics_namespaced() {
    echo "Running in the ${namespace} namespace"
    # -- Pods --
    echo -e "Fetching all pods <pods>"
    "${here}/ops.bash" kubectl "${cluster}" get pods -n "${namespace}" -o yaml
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Top --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Fetching pods resources usage"
    "${here}/ops.bash" kubectl "${cluster}" top pods -n "${namespace}"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Deployments --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Fetching Deployments <deployments>"
    "${here}/ops.bash" kubectl "${cluster}" get deployments -n "${namespace}" -o yaml
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Daemonsets --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Fetching Daemonsets <daemonsets>"
    "${here}/ops.bash" kubectl "${cluster}" get daemonsets -n "${namespace}" -o yaml
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Statefulsets --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Fetching Statefulsets <statefulsets>"
    "${here}/ops.bash" kubectl "${cluster}" get statefulsets -n "${namespace}" -o yaml
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Events --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Fetching Events <events>"
    "${here}/ops.bash" kubectl "${cluster}" get events -n "${namespace}"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- ConfigMaps --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Fetching ConfigMaps <configmaps>"
    cfg1=$("${here}/ops.bash" kubectl "${cluster}" get pods -n "${namespace}" -o yaml | yq4 '.items[] | select(.status.conditions[] | select(.type != "Ready" and .status != "True")) | [.spec.volumes[].configMap.name]')
    readarray cfg1_arr < <(echo "$cfg1" | yq4 e -o=j -I=0 '.[]')
    cfg2=$("${here}/ops.bash" kubectl "${cluster}" get pods -n "${namespace}" -o yaml | yq4 '.items[] | select(.status.conditions[] | select(.type != "Ready" and .status != "True")) | .spec.containers[].envFrom[].configMapRef.name')
    readarray cfg2_arr < <(echo "$cfg2" | yq4 e -o=j -I=0 '.[]')
    cfg3=$("${here}/ops.bash" kubectl "${cluster}" get pods -n "${namespace}" -o yaml | yq4 '.items[] | select(.status.conditions[] | select(.type != "Ready" and .status != "True")) | .spec.containers[].env[].ValueFrom.configMapKeyRef.name')
    readarray cfg3_arr < <(echo "$cfg3" | yq4 e -o=j -I=0 '.[]')
    cfgs=("${cfg1_arr[@]}" "${cfg2_arr[@]}" "${cfg3_arr[@]}")
    # shellcheck disable=SC2060
    # shellcheck disable=SC2207
    cfgs=($(echo "${cfgs[@]}" | tr [:space:] '\n' | awk '!a[$0]++'))

    for cfg in "${cfgs[@]}"; do
        if [ "$cfg" == "null" ]; then
            :
        else
            configmap=$(sed -e 's/^"//' -e 's/"$//' <<<"$cfg")
            "${here}/ops.bash" kubectl "${cluster}" get configmap -n "${namespace}" "$configmap" -o yaml
        fi
    done
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' '

    # -- Logs --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' '
    echo "Fetching Logs <logs>"
    pods=$("{$here}/ops.bash" kubectl "${cluster}" get pods -n "${namespace}" -o yaml | yq4 '.items[] | .metadata.name')
    readarray pods_arr < <(echo "$pods" | yq4 e -o=j -I=0 '.[]')

    for pod in "${pods_arr[@]}"; do
        echo "Error logs for pod: ${pod}"
        "${here}/ops.bash" kubectl "${cluster}" logs -n "${namespace}" "${pods}" | grep -e error -e err
    done
}

log_info "Running diagnostics..."
config_load "${1}"
if [ -z "${namespace}" ]; then
    run_diagnostics >"${file}" 2>&1
else
    run_diagnostics_namespaced >"${file}" 2>&1
fi
log_info "Diagnostics done. Saving and encrypting file ${file}"

sops_encrypt_file "${file}"
