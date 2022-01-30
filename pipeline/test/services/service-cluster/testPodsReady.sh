#!/bin/bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/funcs.sh
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

enable_harbor=$(yq r -e "${CONFIG_FILE}" 'harbor.enabled')
enable_harbor_backup=$(yq r -e "${CONFIG_FILE}" 'harbor.backup.enabled')
enable_user_grafana=$(yq r -e "${CONFIG_FILE}" 'user.grafana.enabled')
enable_fluentd=$(yq r -e "${CONFIG_FILE}" 'fluentd.enabled')
enable_opensearch_snapshot=$(yq r -e "${CONFIG_FILE}" 'opensearch.snapshot.enabled')
enable_influxdb_backup=$(yq r -e "${CONFIG_FILE}" 'influxDB.backup.enabled')
enable_influxdb_backup_retention=$(yq r -e "${CONFIG_FILE}" 'influxDB.backupRetention.enabled')
enable_velero=$(yq r -e "${CONFIG_FILE}" 'velero.enabled')
enable_local_pv_provisioner=$(yq r -e "${CONFIG_FILE}" 'storageClasses.local.enabled')
enable_nfs_provisioner=$(yq r -e "${CONFIG_FILE}" 'storageClasses.nfs.enabled')
enable_os_data_sts=$(yq r -e "${CONFIG_FILE}" 'opensearch.dataNode.dedicatedPods')
enable_os_client_sts=$(yq r -e "${CONFIG_FILE}" 'opensearch.clientNode.dedicatedPods')
enable_thanos=$(yq r -e "${CONFIG_FILE}" 'thanos.enabled')
enable_thanos_query=$(yq r -e "${CONFIG_FILE}" 'thanos.query.enabled')
enable_thanos_receiver=$(yq r -e "${CONFIG_FILE}" 'thanos.receiver.enabled')
enable_thanos_ruler=$(yq r -e "${CONFIG_FILE}" 'thanos.ruler.enabled')
enable_influxdb=$(yq r -e "${CONFIG_FILE}" 'influxDB.enabled')

echo
echo
echo "Testing deployments"
echo "==================="

deployments=(
    "dex dex"
    "cert-manager cert-manager"
    "cert-manager cert-manager-cainjector"
    "cert-manager cert-manager-webhook"
    "kube-system calico-kube-controllers"
    "kube-system coredns"
    "kube-system metrics-server"
    "ingress-nginx ingress-nginx-default-backend"
    "monitoring kube-prometheus-stack-operator"
    "monitoring kube-prometheus-stack-grafana"
    "monitoring kube-prometheus-stack-kube-state-metrics"
    "monitoring prometheus-blackbox-exporter"
    "opensearch-system prometheus-elasticsearch-exporter"
    "opensearch-system opensearch-dashboards"
)
if "${enable_nfs_provisioner}"; then
    deployments+=("kube-system nfs-subdir-external-provisioner")
fi
if "${enable_harbor}"; then
    deployments+=(
        "harbor harbor-harbor-chartmuseum"
        "harbor harbor-harbor-core"
        "harbor harbor-harbor-jobservice"
        "harbor harbor-harbor-notary-server"
        "harbor harbor-harbor-notary-signer"
        "harbor harbor-harbor-portal"
        "harbor harbor-harbor-registry"
    )
fi
if "${enable_user_grafana}"; then
    deployments+=("monitoring user-grafana")
fi
if "${enable_velero}"; then
    deployments+=("velero velero")
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
    read -r -a arr <<< "$deployment"
    namespace="${arr[0]}"
    name="${arr[1]}"
    testResourceExistenceFast "${resourceKind}" "${namespace}" "${name}" "${simpleData}"
done

echo
echo
echo "Testing daemonsets"
echo "=================="

daemonsets=(
    "kube-system calico-node"
    "kube-system node-local-dns"
    "ingress-nginx ingress-nginx-controller"
    "monitoring kube-prometheus-stack-prometheus-node-exporter"
)
if "${enable_local_pv_provisioner}"; then
  daemonsets+=("kube-system local-volume-provisioner")
fi
if "${enable_fluentd}"; then
    daemonsets+=("fluentd fluentd")
fi
if "$enable_velero"; then
    daemonsets+=("velero restic")
fi

resourceKind="DaemonSet"
# Get json data in a smaller dataset
simpleData="$(getStatus $resourceKind)"
for daemonset in "${daemonsets[@]}"; do
    read -r -a arr <<< "$daemonset"
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
        "harbor harbor-harbor-database"
        "harbor harbor-harbor-redis"
        "harbor harbor-harbor-trivy"
    )
fi
if "${enable_fluentd}"; then
    statefulsets+=("fluentd fluentd")
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
if "${enable_influxdb}"; then
    statefulsets+=(
        "monitoring prometheus-wc-reader-prometheus-instance"
        "influxdb-prometheus influxdb"
    )
fi

resourceKind="StatefulSet"
# Get json data in a smaller dataset
simpleData="$(getStatus $resourceKind)"
for statefulset in "${statefulsets[@]}"; do
    read -r -a arr <<< "$statefulset"
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
    read -r -a arr <<< "$job"
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
# influxdb cronjob is create by <template name>-metrics-retention-cronjob-<sc/wc>
# If the template name changes this has to be changed aswell.
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
if "${enable_influxdb_backup}"; then
    cronjobs+=("influxdb-prometheus influxdb-backup")
fi
if "${enable_influxdb_backup_retention}"; then
    cronjobs+=("influxdb-prometheus influxdb-backup-retention")
fi
if "${enable_fluentd}"; then
    cronjobs+=("fluentd sc-logs-retention")
fi
if "${enable_influxdb}"; then
    cronjobs+=(
        "influxdb-prometheus influxdb-metrics-retention-cronjob-sc"
        "influxdb-prometheus influxdb-metrics-retention-cronjob-wc"
    )
fi

echo
echo
echo "Testing cronjobs"
echo "===================="

for cronjob in "${cronjobs[@]}"; do
    read -r -a arr <<< "$cronjob"
    namespace="${arr[0]}"
    name="${arr[1]}"
    echo -n -e "\n${name}\t"
    if testResourceExistence cronjob "${namespace}" "${name}"; then
        logCronJob "${namespace}" "${name}"
    fi
done
