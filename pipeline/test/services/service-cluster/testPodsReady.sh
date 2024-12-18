#!/usr/bin/env bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/funcs.sh
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

enable_harbor=$(yq4 -e '.harbor.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_harbor_backup=$(yq4 -e '.harbor.backup.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_user_grafana=$(yq4 -e '.grafana.user.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_fluentd=$(yq4 -e '.fluentd.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_fluentd_audit=$(yq4 -e '.fluentd.audit.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_fluentd_logs=$(yq4 -e '.fluentd.scLogs.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_opensearch_snapshot=$(yq4 -e '.opensearch.snapshot.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_velero=$(yq4 -e '.velero.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_os_data_sts=$(yq4 -e '.opensearch.dataNode.dedicatedPods' "${CONFIG_FILE}" 2>/dev/null)
enable_os_client_sts=$(yq4 -e '.opensearch.clientNode.dedicatedPods' "${CONFIG_FILE}" 2>/dev/null)
enable_thanos=$(yq4 -e '.thanos.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_thanos_query=$(yq4 -e '.thanos.query.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_thanos_receiver=$(yq4 -e '.thanos.receiver.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_thanos_ruler=$(yq4 -e '.thanos.ruler.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_kured=$(yq4 -e '.kured.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_falco_alerts=$(yq4 -e '.falco.alerts.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_falco=$(yq4 -e '.falco.enabled' "${CONFIG_FILE}" 2>/dev/null)

echo
echo
echo "Testing deployments"
echo "==================="

deployments=(
  "dex dex"
  "cert-manager cert-manager"
  "cert-manager cert-manager-cainjector"
  "cert-manager cert-manager-webhook"
  "kube-system coredns"
  "kube-system metrics-server"
  "ingress-nginx ingress-nginx-default-backend"
  "monitoring kube-prometheus-stack-operator"
  "monitoring ops-grafana"
  "monitoring kube-prometheus-stack-kube-state-metrics"
  "monitoring prometheus-blackbox-exporter"
  "opensearch-system prometheus-opensearch-exporter"
  "opensearch-system opensearch-dashboards"
)
if "${enable_harbor}"; then
  deployments+=(
    "harbor harbor-core"
    "harbor harbor-jobservice"
    "harbor harbor-portal"
    "harbor harbor-registry"
  )
fi
if "${enable_user_grafana}"; then
  deployments+=("monitoring user-grafana")
fi
if "${enable_velero}"; then
  deployments+=("velero velero")
fi
if "${enable_falco}" && "${enable_falco_alerts}"; then
  deployments+=("falco falco-falcosidekick")
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_receiver}" == "true" ]]; then
  deployments+=(
    "thanos thanos-receiver-bucketweb"
    "thanos thanos-receiver-compactor"
    "thanos thanos-receiver-receive-distributor"
  )
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_query}" == "true" ]]; then
  deployments+=(
    "thanos thanos-query-query"
    "thanos thanos-query-query-frontend"
  )
fi

resourceKind="Deployment"
# Get json data in a smaller dataset
simpleData="$(getStatus $resourceKind)"
for deployment in "${deployments[@]}"; do
  read -r -a arr <<<"$deployment"
  namespace="${arr[0]}"
  name="${arr[1]}"
  testResourceExistenceFast "${resourceKind}" "${namespace}" "${name}" "${simpleData}"
done

echo
echo
echo "Testing daemonsets"
echo "=================="

daemonsets=(
  "kube-system node-local-dns"
  "ingress-nginx ingress-nginx-controller"
  "monitoring kube-prometheus-stack-prometheus-node-exporter"
)
if "${enable_fluentd}"; then
  daemonsets+=("fluentd-system fluentd-forwarder")
fi
if "$enable_velero"; then
  daemonsets+=("velero node-agent")
fi
if "${enable_kured}"; then
  daemonsets+=("kured kured")
fi
if "${enable_falco}"; then
  daemonsets+=("falco falco")
fi
resourceKind="DaemonSet"
# Get json data in a smaller dataset
simpleData="$(getStatus $resourceKind)"
for daemonset in "${daemonsets[@]}"; do
  read -r -a arr <<<"$daemonset"
  namespace="${arr[0]}"
  name="${arr[1]}"
  testResourceExistenceFast ${resourceKind} "${namespace}" "${name}" "${simpleData}"
done

echo
echo
echo "Testing statefulsets"
echo "===================="

statefulsets=(
  "monitoring prometheus-kube-prometheus-stack-prometheus"
  "monitoring alertmanager-kube-prometheus-stack-alertmanager"
  "opensearch-system opensearch-master"
)
if "${enable_os_data_sts}"; then
  statefulsets+=("opensearch-system opensearch-data")
fi
if "${enable_os_client_sts}"; then
  statefulsets+=("opensearch-system opensearch-client")
fi
if "${enable_harbor}"; then
  statefulsets+=(
    "harbor harbor-database"
    "harbor harbor-redis"
    "harbor harbor-trivy"
  )
fi
if "${enable_fluentd}"; then
  statefulsets+=("fluentd-system fluentd-aggregator")
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_receiver}" == "true" ]]; then
  statefulsets+=(
    "thanos thanos-receiver-receive"
    "thanos thanos-receiver-storegateway"
  )
fi
if [[ "${enable_thanos}" == "true" ]] && [[ "${enable_thanos_ruler}" == "true" ]]; then
  statefulsets+=("thanos thanos-receiver-ruler")
fi

resourceKind="StatefulSet"
# Get json data in a smaller dataset
simpleData="$(getStatus $resourceKind)"
for statefulset in "${statefulsets[@]}"; do
  read -r -a arr <<<"$statefulset"
  namespace="${arr[0]}"
  name="${arr[1]}"
  testResourceExistenceFast ${resourceKind} "${namespace}" "${name}" "${simpleData}"
done

# Format:
# namespace job-name timeout
jobs=(
  "opensearch-system opensearch-configurer 120s"
)
if "${enable_harbor}"; then
  jobs+=("harbor init-harbor-job 120s")
fi

echo
echo
echo "Testing jobs"
echo "===================="

for job in "${jobs[@]}"; do
  read -r -a arr <<<"$job"
  namespace="${arr[0]}"
  name="${arr[1]}"
  timeout="${arr[2]}"
  echo -n -e "\n${name}\t"
  if testResourceExistence job "${namespace}" "${name}"; then
    testJobStatus "${namespace}" "${name}" "${timeout}"
  fi
done

# Format:
# namespace cronjob-name timeout
# If the template name changes this has to be changed as well.
cronjobs=(
  "opensearch-system opensearch-curator"
)
if "${enable_harbor}" && "${enable_harbor_backup}"; then
  cronjobs+=("harbor harbor-backup-cronjob")
fi
if "${enable_opensearch_snapshot}"; then
  cronjobs+=(
    "opensearch-system opensearch-backup"
    "opensearch-system opensearch-slm"
  )
fi
if "${enable_fluentd_audit}"; then
  cluster_name="$(yq4 '.global.clusterName' "${CONFIG_FILE}" 2>/dev/null)"
  mapfile -t clusters_monitoring < <(yq4 '.global.clustersMonitoring[]' "${CONFIG_FILE}" 2>/dev/null)

  cronjobs+=(
    "fluentd-system audit-$cluster_name-compaction"
    "fluentd-system audit-$cluster_name-retention"
  )
  for cluster in "${clusters_monitoring[@]}"; do
    cronjobs+=(
      "fluentd-system audit-$cluster-compaction"
      "fluentd-system audit-$cluster-retention"
    )
  done
fi
if "${enable_fluentd_logs}"; then

  cronjobs+=(
    "fluentd-system sc-logs-logs-compaction"
    "fluentd-system sc-logs-logs-retention"
  )
fi

echo
echo
echo "Testing cronjobs"
echo "===================="

for cronjob in "${cronjobs[@]}"; do
  read -r -a arr <<<"$cronjob"
  namespace="${arr[0]}"
  name="${arr[1]}"
  echo -n -e "\n${name}\t"
  if testResourceExistence cronjob "${namespace}" "${name}" && [ "$LOGGING" == "--logging-enabled" ]; then
    logCronJob "${namespace}" "${name}"
  fi
done
