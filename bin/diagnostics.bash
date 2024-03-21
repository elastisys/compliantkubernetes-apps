#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

cluster="${1}"

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
    # -- Nodes --
    echo "Fetching Nodes that are NotReady (<node>)"
    nodes=$("${here}/ops.bash" kubectl "${cluster}" get nodes -o=yaml | yq4 '.items[] | select(.status.conditions[] | select(.type == "Ready" and .status != "True")) | .metadata.name' | tr '\n' ' ')
    echo "${nodes}" | xargs "${here}/ops.bash" kubectl "${cluster}" get nodes -o wide
    echo -e "\nDescribing Nodes"
    echo "${nodes}" | xargs "${here}/ops.bash" kubectl "${cluster}" describe nodes


    # -- DS and Deployments --
    echo -e "\nFetching Deployments without desired number of ready pods (<deployment>)"
    "${here}/ops.bash" kubectl "${cluster}" get deployments -A -o wide | grep -v -E "([0-9]+)/\1"

    echo -e "\nFetching DaemonSets without desired number of ready pods (<daemonset>)"
    "${here}/ops.bash" kubectl "${cluster}" get daemonsets -A -o wide | grep -v -E "([0-9]+)/\1"

    echo -e "\nFetching StatefulSets without desired number of ready pods (<statefulset>)"
    "${here}/ops.bash" kubectl "${cluster}" get statefulsets -A -o wide | grep -v -E "([0-9]+)/\1"

    # -- Pods --
    echo -e "\nFetching Pods that are NotReady (<pod>)"

    "${here}/ops.bash" kubectl "${cluster}" get pods -A -o wide | grep -v -E "Running|Completed"
    pods=$("${here}/ops.bash" kubectl "${cluster}" get pod -A -o=yaml | yq4 '.items[] | select(.status.conditions[] | select(.type == "Ready" and .status != "True" and .reason != "PodCompleted")) | [{"name": .metadata.name, "namespace": .metadata.namespace}]')
    readarray pod_arr < <(echo "$pods" | yq4 e -o=j -I=0 '.[]')

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

    # -- Top --
    echo -e "\nFetching cluster resource usage <top>"
    "${here}/ops.bash" kubectl "${cluster}" top nodes
    "${here}/ops.bash" kubectl "${cluster}" top pods -A

    # -- Helm --
    echo -e "\nFetching Helm releases that are not deployed (<helm>)"
    "${here}/ops.bash" helm "${cluster}" list -A --all | grep -v deployed

    # -- Cert --
    echo -e "\nFetching cert-manager resources (<cert>)"
    "${here}/ops.bash" kubectl "${cluster}" get clusterissuers,issuers,certificates,orders,challenges --all-namespaces -o wide

    echo -e "\nDescribing failed Challenges (<challenge>)"
    challenges=$("${here}/ops.bash" kubectl "${cluster}" get challenge -A -o=yaml | yq4 '.items[] | select(.status.state != "valid") | [{"name": .metadata.name, "namespace": .metadata.namespace}]')
    readarray challenge_arr < <(echo "$challenges" | yq4 e -o=j -I=0 '.[]')
    for challenge in "${challenge_arr[@]}"; do
        challenge_name=$(echo "$challenge" | jq -r '.name')
        namespace=$(echo "$challenge" | jq -r '.namespace')
        "${here}/ops.bash" kubectl "${cluster}" describe challenge "${challenge_name}" -n "${namespace}"
    done

    # -- Events --
    echo -e "\nFetching all Events (<event>)"
    "${here}/ops.bash" kubectl "${cluster}" get events -A --sort-by=.metadata.creationTimestamp
}

log_info "Running diagnostics..."
run_diagnostics > "${file}" 2>&1
log_info "Diagnostics done. Saving and encrypting file ${file}"

sops_encrypt_file "${file}"
