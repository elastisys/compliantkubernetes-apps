#!/usr/bin/env bash

# Set variables and array adapted for the workload cluster and call functions in prometheus-common

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/prometheus-common.sh
source "$INNER_SCRIPTS_PATH/../prometheus-common.sh"

# Get amount of nodes in cluster
totalNodes=$(kubectl get nodes --no-headers | wc -l)
masterNodes=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)

echo
echo
echo "Testing workload cluster prometheus"
echo "==================================="

wcTargets=(
    "serviceMonitor/monitoring/kube-prometheus-stack-apiserver/0 ${masterNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-coredns/0 2"
    "serviceMonitor/monitoring/kube-prometheus-stack-kube-etcd/0 ${masterNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-kube-proxy/0 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-kube-state-metrics/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-kubelet/0 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-kubelet/1 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-operator/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-prometheus-node-exporter/0 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-prometheus/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-falco/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-gatekeeper/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-nginx/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-prometheus/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-sc-dex/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-sc-opensearch-ops/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-sc-thanos-recv-ops/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-sc-user-grafana/0 1"
    "serviceMonitor/monitoring/trivy-operator/0 1"
)

test_targets_retry "svc/kube-prometheus-stack-prometheus" "${wcTargets[@]}"
