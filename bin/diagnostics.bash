#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
    log_info "usage: ck8s diagnostics <sc|wc> [command] [options]"
    log_info ""
    log_info "Collects diagnostics from the current environment set by CK8S_CONFIG_PATH and"
    log_info "store them in a file in the CK8S_CONFIG_PATH directory encrypted with SOPS using"
    log_info "by default GPG keys found in CK8S_CONFIG_PATH/diagnostics_receiver.gpg or by"
    log_info "setting the CK8S_PGP_FP environment variable manually."
    log_info ""
    log_info "Commands:"
    log_info "     namespace                     run diagnostics for specified namespace only"
    log_info "     query-default-metrics-since   query a predefined set of metrics since the specified date"
    log_info "     query-metric                  query any arbitrary metric"
    log_info ""
    log_info "Global options:"
    log_info " -h, --help                        display help for this command and exit"
    log_info "     --include-config              include config yaml files found in CK8S_CONFIG_PATH"
    exit 1
}

gpg_file="${CK8S_CONFIG_PATH}/diagnostics_receiver.gpg"
include_config=false
cluster="${1}"
sub_command=""
command_arg=""

shift

while [ "${#}" -gt 0 ] ; do
    case "${1}" in
        -h | --help)
            usage
            ;;
        --include-config)
            include_config=true
            ;;
        namespace|query-default-metrics-since|query-metric)
            [[ ${#} -ge 2 && "${2}" != -* && -z "$sub_command" ]] || usage
            sub_command="${1:-}"
            command_arg="${2:-}"
            shift
            ;;
        *)
            log_error "ERROR: invalid argument: \"${1:-}\""
            usage
            ;;
    esac
    shift
done

log_self_managed_notice() {
    log_warning "WARNING: Notice for self-managed customers:"

    echo -e "\tIf you are an Elastisys self-managed customer, you can send diagnostic data to Elastisys." 1>&2
    echo -e "\tMake sure to store GPG keys retrieved during onboarding in a file named:\n" 1>&2
    echo -e "\t\${CK8S_CONFIG_PATH}/diagnostics_receiver.gpg\n" 1>&2

    echo -e "\tIf you are an Elastisys self-managed customer, you get support by contacting sme-support@elastisys.com\n" 1>&2

    usage
}

import_gpg_file() {
    local fingerprints
    local gpg_file="${1}"
    if [[ ! -f "${gpg_file}" ]]; then
        log_error "ERROR: file \"${gpg_file}\" not found"
        log_self_managed_notice
    fi
    log_info "Attempting to import GPG keys from ${gpg_file}"

    if ! gpg --import "${gpg_file}"; then
        log_error "ERROR: Could not import GPG keys from ${gpg_file}"
        log_self_managed_notice
    fi

    # get only fingerprints used for encryption
    mapfile -t fingerprints < <(gpg --with-colons --import-options show-only --import --fingerprint "${CK8S_CONFIG_PATH}/diagnostics_receiver.gpg" | awk -F: '
        /^fpr/ {
            if (!main_fpr) {
                print $10;
                main_fpr = 1;
            }
        }
        /^pub/ {
            main_fpr = 0;
        }'
    )
    CK8S_PGP_FP=$(IFS=, ; echo "${fingerprints[*]}")
}

sops_encrypt_file() {
    if [ -z "${CK8S_PGP_FP:-}" ]; then
        sops_encrypt "${file}"
        return
    fi

    log_info "Encrypting ${file}"

    sops --pgp "${CK8S_PGP_FP}" -e -i "${file}"
}

fetch_oidc_token() {
    # shellcheck disable=SC2016
    readarray -t args <<< "$(yq4 '. as $root | ($root.contexts[] | select(.name == $root.current-context) | .context) as $context | ($root.users[] | select(.name == $context.user) | .user) as $user | $user.exec.args[]' "${config["kube_config_sc"]}")"
    [[ "${args[0]}" == "oidc-login" ]] || log_fatal "ERROR: This command requires the kubeconfig to use OIDC"
    kubectl "${args[@]}" | yq4 '.status.token'
}

run_diagnostics() {
    # -- ck8s --
    echo "Fetching CK8S software versions"
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    if [ -d "${CK8S_CONFIG_PATH}/capi" ]; then
        # shellcheck disable=SC2002
        capi_version=$(cat "${CK8S_CONFIG_PATH}/capi/defaults/values.yaml" | yq4 '.clusterApiVersion')
        echo "CAPI version: ${capi_version}"
    elif [ -d "${CK8S_CONFIG_PATH}/${cluster}-config" ]; then
        # shellcheck disable=SC2002
        kubespray_version=$(cat "${CK8S_CONFIG_PATH}/${cluster}-config/group_vars/all/ck8s-kubespray-general.yaml" | yq4 '.ck8sKubesprayVersion')
        echo "Kubespray version: ${kubespray_version}"
    else
        echo "Can't find config directory"
    fi
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    # shellcheck disable=SC2002
    apps_version=$(cat "${CK8S_CONFIG_PATH}/defaults/common-config.yaml" | yq4 '.global.ck8sVersion')
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
    helm=$("${here}"/ops.bash helm "${cluster}" list -A --all -o yaml | yq4 '.[] | select(.status != "deployed")')
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
    namespace="${1}"
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
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    # -- Logs --
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Fetching Logs <logs>"
    pods=$("${here}/ops.bash" kubectl "${cluster}" get pods -n "${namespace}" -o yaml | yq4 '.items[] | .metadata.name')
    readarray pods_arr < <(echo "$pods" | yq4 e -o=j -I=0 '.[]')

    for pod in "${pods_arr[@]}"; do
        echo "Error logs for pod: ${pod}"
        "${here}/ops.bash" kubectl "${cluster}" logs -n "${namespace}" "${pods}" | grep -e error -e err
    done
}

get_config_files() {
    mapfile -t config_files < <(find "${CK8S_CONFIG_PATH}" -name "*-config.yaml")

    for config_file in "${config_files[@]}"; do
        printf '\n%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
        echo -n "Config file: "
        if [[ $(basename "$(dirname "${config_file}")") == "defaults" ]]; then
            echo "defaults/$(basename "${config_file}")"
        else
            basename "${config_file}"
        fi
        cat "${config_file}"
    done
}

run_diagnostics_default_metrics() {
    token="$(fetch_oidc_token)"
    domain="https://kube.$(yq4 '.global.opsDomain' "${config["config_file_sc"]}"):6443"
    endpoint="${domain}/api/v1/namespaces/thanos/services/thanos-query-query-frontend:9090/proxy/api/v1"
    header="Authorization: Bearer ${token}"
    range_arg=("--data-urlencode" "start=$(date -d -"${1}" -Iseconds)" "--data-urlencode" "end=$(date -Iseconds)" "--data-urlencode" "step=1m")

    query_and_parse() {
        query="${1}"
        print_func="${2}"
        res="$(curl "${endpoint}/query_range" -k -s --header "${header}" --data-urlencode query="${query}" "${range_arg[@]}")"
        if [[ $(jq '.data.result | length' <<< "${res}") -gt 0  ]]; then
            readarray metric_results_arr < <(jq -c '.data.result[]' <<< "${res}")
            for row in "${metric_results_arr[@]}"; do
                "${print_func}" "${row}"
            done
        fi
    }

    print_fluentd() {
        echo "Fluentd output error rate over 0 on the dates:"
        jq '.values[][0]' <<< "${1}" | xargs -I {} date -d@{}
        echo
    }

    # Fluentd output error/retry rate
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Querying fluentd output error rate."
    query_and_parse 'sum(rate(fluentd_output_status_retry_count[1m])) > 0' print_fluentd

    print_dropped_packages() {
        direction="$([[ $(jq -r .metric.type <<< "${1}") == "fw" ]] && echo "from" || echo "to")"
        pod="$(jq '.metric.exported_pod' <<< "${1}")"
        echo "Found dropped packages going ${direction} pod: ${pod} on dates:"
        jq '.values[][0]' <<< "${1}" | xargs -I {} date -d@{}
        echo
    }

    # Dropped packets going from pod
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Querying dropped packages."
    query_and_parse 'rate(no_policy_drop_counter[1m]) > 0' print_dropped_packages

    print_uptime() {
        echo "The target $(jq '.metric.target' <<< "${1}") was down on dates:"
        jq '.values[][0]' <<< "${1}" | xargs -I {} date -d@{}
        echo
    }

    # Uptime
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Querying uptime."
    query_and_parse 'max by (target) (probe_success) < 1' print_uptime

    # Opensearch status <instant Query>
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo "Querying Opensearch cluster status"
    res="$(curl "${endpoint}/query" -k -s --header "${header}" --data-urlencode query='elasticsearch_cluster_health_status{color=~"yellow|red"} > 0')"
    if [[ $(jq '.data.result | length' <<< "${res}" ) -gt 0 ]]; then
        echo "Opensearch is in $(jq '.data.result[0].metric.color' <<< "${res}") state!"
    fi
}

# run_diagnostics_query_metric <metric>
run_diagnostics_query_metric() {
    token=$(fetch_oidc_token)
    domain="https://kube.$(yq4 '.global.opsDomain' "${config["config_file_sc"]}"):6443"
    endpoint="${domain}/api/v1/namespaces/thanos/services/thanos-query-query-frontend:9090/proxy/api/v1"
    header="Authorization: Bearer ${token}"

    curl "${endpoint}/query" -k --header "${header}" --data-urlencode query="${1}" | jq
}

if [[ -z "${CK8S_PGP_FP:-}" ]]; then
    import_gpg_file "${gpg_file}"
fi
log_info "Using the following fingerprints:"
log_info "${CK8S_PGP_FP}"

file="${CK8S_CONFIG_PATH}/diagnostics-${cluster}-$(date +%y%m%d%H%M%S).log"
touch "${file}"

config_load "${cluster}"
log_info "Running diagnostics..."
export CK8S_AUTO_APPROVE=true

case "${sub_command}" in
    namespace)
        # check that namespace exists
        "${here}/ops.bash" kubectl "${cluster}" get namespace "${command_arg}" >/dev/null
        run_diagnostics_namespaced "${command_arg}" >"${file}" 2>&1
        ;;
    query-default-metrics-since)
        # Verify date argument
        date -d -"${command_arg}" >/dev/null
        run_diagnostics_default_metrics "${command_arg}" >"${file}" 2>&1
        ;;
    query-metric)
        run_diagnostics_query_metric "${command_arg}" >"${file}" 2>&1
        ;;
    *)
        run_diagnostics >"${file}" 2>&1
        ;;
esac

if [[ "${include_config}" == "true" ]]; then
    get_config_files >>"${file}" 2>&1
fi

log_info "Diagnostics done. Saving and encrypting file ${file}"

sops_encrypt_file "${file}"
