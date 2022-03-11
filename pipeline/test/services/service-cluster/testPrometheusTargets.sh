#!/bin/bash

# Set variables and array adapted for the service cluster and call functions in prometheus-common

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/prometheus-common.sh
source "$INNER_SCRIPTS_PATH/../prometheus-common.sh"

# Get amount of nodes in cluster
totalNodes=$(kubectl get nodes --no-headers | wc -l)
masterNodes=$(kubectl get nodes -l node-role.kubernetes.io/master --no-headers | wc -l)

enable_thanos=$(yq r -e "${CONFIG_FILE}" 'thanos.enabled')
enable_thanos_receiver=$(yq r -e "${CONFIG_FILE}" 'thanos.receiver.enabled')
enable_thanos_query=$(yq r -e "${CONFIG_FILE}" 'thanos.query.enabled')
enable_thanos_ruler=$(yq r -e "${CONFIG_FILE}" 'thanos.ruler.enabled')
enable_thanos_service_monitor=$(yq r -e "${CONFIG_FILE}" 'thanos.metrics.serviceMonitor.enabled')

echo
echo
echo "Testing service cluster prometheus"
echo "=================================="

# Not using these targets atm
# TODO: add elements to the list when they start being used.
# "monitoring/kube-prometheus-stack-kube-etcd/0 1"
# "monitoring/kube-prometheus-stack-kube-proxy/0 1"
scTargets=(
    "serviceMonitor/opensearch-system/prometheus-elasticsearch-exporter/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-user-api-server/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-dex/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-grafana/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-opensearch-dashboards/0 1"
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
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_service_monitor}" == "true" ]] && [[ "${enable_thanos_receiver}" == "true" ]]; then
    scTargets+=(
        "serviceMonitor/thanos/thanos-receiver-bucketweb/0 1"
        "serviceMonitor/thanos/thanos-receiver-compactor/0 1"
        "serviceMonitor/thanos/thanos-receiver-receive/0 3"
        "serviceMonitor/thanos/thanos-receiver-storegateway/0 1"
    )
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_service_monitor}" == "true" ]] && [[ "${enable_thanos_ruler}" == "true" ]]; then
    scTargets+=("serviceMonitor/thanos/thanos-receiver-ruler/0 2")
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_service_monitor}" == "true" ]] && [[ "${enable_thanos_query}" == "true" ]]; then
    scTargets+=(
        "serviceMonitor/thanos/thanos-query-query/0 1"
        "serviceMonitor/thanos/thanos-query-query-frontend/0 1"
    )
fi

test_targets_retry "svc/kube-prometheus-stack-prometheus" "${scTargets[@]}"
