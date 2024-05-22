#!/usr/bin/env bash

# Set variables and array adapted for the service cluster and call functions in prometheus-common

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/prometheus-common.sh
source "$INNER_SCRIPTS_PATH/../prometheus-common.sh"

# Get amount of nodes in cluster
totalNodes=$(kubectl get nodes --no-headers | wc -l)
masterNodes=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)

totalPrometheus=$(yq4 -e '.prometheus.replicas' "${CONFIG_FILE}")

enable_thanos=$(yq4 -e '.thanos.enabled' "${CONFIG_FILE}")
enable_thanos_receiver=$(yq4 -e '.thanos.receiver.enabled' "${CONFIG_FILE}")
enable_thanos_query=$(yq4 -e '.thanos.query.enabled' "${CONFIG_FILE}")
enable_thanos_ruler=$(yq4 -e '.thanos.ruler.enabled' "${CONFIG_FILE}")
enable_thanos_service_monitor=$(yq4 -e '.thanos.metrics.serviceMonitor.enabled' "${CONFIG_FILE}")
readarray -t custom_kubeapi_targets < <(yq4 -e '.prometheusBlackboxExporter.customKubeapiTargets[].name' "${CONFIG_FILE}")

echo
echo
echo "Testing service cluster prometheus"
echo "=================================="

# Not using these targets atm
# TODO: add elements to the list when they start being used.
# "monitoring/kube-prometheus-stack-kube-etcd/0 1"
# "monitoring/kube-prometheus-stack-kube-proxy/0 1"
scTargets=(
    "serviceMonitor/opensearch-system/prometheus-opensearch-exporter/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-dex/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-grafana/0 1"
    "serviceMonitor/monitoring/prometheus-blackbox-exporter-opensearch-dashboards/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-alertmanager/0 2"
    "serviceMonitor/monitoring/kube-prometheus-stack-apiserver/0 ${masterNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-coredns/0 2"
    "serviceMonitor/monitoring/ops-grafana/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-kube-state-metrics/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-kubelet/0 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-kubelet/1 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-prometheus-node-exporter/0 ${totalNodes}"
    "serviceMonitor/monitoring/kube-prometheus-stack-operator/0 1"
    "serviceMonitor/monitoring/kube-prometheus-stack-prometheus/0 ${totalPrometheus}"
)
if [ ${#custom_kubeapi_targets[@]} -gt 0 ]; then
    for target_name in "${custom_kubeapi_targets[@]}"; do
        scTargets+=("serviceMonitor/monitoring/prometheus-blackbox-exporter-${target_name}/0 1")
    done
else
    scTargets+=("serviceMonitor/monitoring/prometheus-blackbox-exporter-user-api-server/0 1")
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_service_monitor}" == "true" ]] && [[ "${enable_thanos_receiver}" == "true" ]]; then
    scTargets+=(
        "serviceMonitor/thanos/thanos-receiver-bucketweb/0 1"
        "serviceMonitor/thanos/thanos-receiver-compactor/0 1"
        "serviceMonitor/thanos/thanos-receiver-receive/0 3"
        "serviceMonitor/thanos/thanos-receiver-storegateway/0 1"
    )
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_service_monitor}" == "true" ]] && [[ "${enable_thanos_ruler}" == "true" ]]; then
    scTargets+=("serviceMonitor/thanos/thanos-receiver-ruler/0 4")
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_service_monitor}" == "true" ]] && [[ "${enable_thanos_query}" == "true" ]]; then
    scTargets+=(
        "serviceMonitor/thanos/thanos-query-query/0 2"
        "serviceMonitor/thanos/thanos-query-query-frontend/0 1"
    )
fi

test_targets_retry "svc/kube-prometheus-stack-prometheus" "${scTargets[@]}"
