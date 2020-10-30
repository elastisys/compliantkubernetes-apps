#!/bin/bash

# Set variables and array adapted for the workload cluster and call functions in prometheus-common

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC1090
source "$INNER_SCRIPTS_PATH/../prometheus-common.sh"

# Get amount of nodes in cluster
totalNodes=$(kubectl get nodes --no-headers | wc -l)
masterNodes=$(kubectl get nodes -l node-role.kubernetes.io/master --no-headers | wc -l)

echo
echo
echo "Testing workload cluster prometheus"
echo "==================================="

# Not using these targets atm
# TODO: add elements to the list when they start being used.
# "monitoring/prometheus-operator-kube-etcd/0 1"
# "monitoring/prometheus-operator-kube-proxy/0 1"
wcTargets=(
    "monitoring/prometheus-operator-apiserver/0 ${masterNodes}"
    "monitoring/prometheus-operator-coredns/0 2"
    "monitoring/prometheus-operator-kube-state-metrics/0 1"
    "monitoring/prometheus-operator-kubelet/0 ${totalNodes}"
    "monitoring/prometheus-operator-kubelet/1 ${totalNodes}"
    "monitoring/prometheus-operator-node-exporter/0 ${totalNodes}"
    "monitoring/prometheus-operator-operator/0 1"
    "monitoring/prometheus-operator-prometheus/0 1"
)

test_targets_retry "svc/prometheus-operator-prometheus" "${wcTargets[@]}"
