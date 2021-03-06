#!/bin/bash

# Set variables and array adapted for the service cluster and call functions in prometheus-common

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/prometheus-common.sh
source "$INNER_SCRIPTS_PATH/../prometheus-common.sh"

# Get amount of nodes in cluster
totalNodes=$(kubectl get nodes --no-headers | wc -l)
masterNodes=$(kubectl get nodes -l node-role.kubernetes.io/master --no-headers | wc -l)

echo
echo
echo "Testing service cluster prometheus"
echo "=================================="

# Not using these targets atm
# TODO: add elements to the list when they start being used.
# "monitoring/kube-prometheus-stack-kube-etcd/0 1"
# "monitoring/kube-prometheus-stack-kube-proxy/0 1"
scTargets=(
    "serviceMonitor/elastic-system/prometheus-elasticsearch-exporter/0 1"
    "serviceMonitor/monitoring/blackbox-exporter-user-api-server/0 1"
    "serviceMonitor/monitoring/blackbox-exporter-dex/0 1"
    "serviceMonitor/monitoring/blackbox-exporter-grafana/0 1"
    "serviceMonitor/monitoring/blackbox-exporter-kibana/0 1"
    "serviceMonitor/monitoring/influxdb-du-monitoring-service-monitor/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-alertmanager/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-apiserver/0 ${masterNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-coredns/0 2"
    "serviceMonitor/monitoring/kube-prometheus-stack-grafana/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-kube-state-metrics/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-kubelet/0 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-kubelet/1 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-node-exporter/0 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-operator/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-prometheus/0 1"
)

test_targets_retry "svc/kube-prometheus-stack-prometheus" "${scTargets[@]}"
