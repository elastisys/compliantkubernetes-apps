#!/bin/bash

# Set variables and array adapted for the service cluster and call functions in prometheus-common

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC1090
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
    "elastic-system/elasticsearch-exporter/0 1"
    "monitoring/blackbox-exporter-user-api-server/0 1"
    "monitoring/blackbox-exporter-dex/0 1"
    "monitoring/blackbox-exporter-grafana/0 1"
    "monitoring/blackbox-exporter-kibana/0 1"
    "monitoring/influxdb-du-monitoring-service-monitor/0 1"
    "monitoring/kube-prometheus-stack-alertmanager/0 1"
    "monitoring/kube-prometheus-stack-apiserver/0 ${masterNodes}"
    "monitoring/kube-prometheus-stack-coredns/0 2"
    "monitoring/kube-prometheus-stack-grafana/0 1"
    "monitoring/kube-prometheus-stack-kube-state-metrics/0 1"
    "monitoring/kube-prometheus-stack-kubelet/0 ${totalNodes}"
    "monitoring/kube-prometheus-stack-kubelet/1 ${totalNodes}"
    "monitoring/kube-prometheus-stack-node-exporter/0 ${totalNodes}"
    "monitoring/kube-prometheus-stack-operator/0 1"
    "monitoring/kube-prometheus-stack-prometheus/0 1"
)

test_targets_retry "svc/kube-prometheus-stack-prometheus" "${scTargets[@]}"

# wc-scraper-prometheus
# Set variables and array adapted for the service cluster (wc-scraper-prometheus service) and call functions in prometheus-common
echo
echo
echo "Testing wc scraper prometheus"
echo "============================="

scraperTargets=(
    "federate-kubelet 1"
    "federate-others 1"
)

test_targets_retry "svc/wc-scraper-prometheus-instance" "${scraperTargets[@]}"
