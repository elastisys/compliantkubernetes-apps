#!/bin/bash

# CK8S operator actions.

set -eu

here="$(dirname "$(readlink -f "$0")")"

# shellcheck source=bin/common.bash
source "${here}/common.bash"

usage() {
    echo "Usage: kubectl <wc|sc> ..." >&2
    echo "       helm <wc|sc> ..." >&2
    echo "       helmfile <wc|sc> ..." >&2
    exit 1
}

# Run arbitrary kubectl commands as cluster admin.
ops_kubectl() {
    case "${1}" in
        sc) kubeconfig="${secrets[kube_config_sc]}" ;;
        wc) kubeconfig="${secrets[kube_config_wc]}" ;;
        *) usage ;;
    esac
    shift
    with_kubeconfig "${kubeconfig}" kubectl "${@}"
}

# Run arbitrary helm commands as cluster admin.
ops_helm() {
    case "${1}" in
        sc) kubeconfig="${secrets[kube_config_sc]}" ;;
        wc) kubeconfig="${secrets[kube_config_wc]}" ;;
        *) usage ;;
    esac
    shift
    with_kubeconfig "${kubeconfig}" helm "${@}"
}

# Run arbitrary Helmfile commands as cluster admin.
ops_helmfile() {
    config_load "$1"

    case "${1}" in
        sc)
            cluster="service_cluster"
            kubeconfig="${secrets[kube_config_sc]}"
        ;;
        wc)
            cluster="workload_cluster"
            kubeconfig="${secrets[kube_config_wc]}"
        ;;
        *) usage ;;
    esac

    shift

    export CONFIG_PATH="${CK8S_CONFIG_PATH}"

    with_kubeconfig "${kubeconfig}" \
        helmfile -f "${here}/../helmfile/" -e ${cluster} "${@}"
}

case "${1}" in
    kubectl)
        shift
        ops_kubectl "${@}"
    ;;
    helm)
        shift
        ops_helm "${@}"
    ;;
    helmfile)
        shift
        ops_helmfile "${@}"
    ;;
    *) usage ;;
esac
