#!/bin/bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC1090
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

cloud_provider=$(yq r -e "${CONFIG_FILE}" 'global.cloudProvider')
enable_harbor=$(yq r -e "${CONFIG_FILE}" 'harbor.enabled')
enable_ck8sdash=$(yq r -e "${CONFIG_FILE}" 'ck8sdash.enabled')
enable_user_grafana=$(yq r -e "${CONFIG_FILE}" 'user.grafana.enabled')
storage_class=$(yq r -e "${CONFIG_FILE}" 'global.storageClass')
elasticsearch_storage_class=$(yq r -e "${CONFIG_FILE}" 'elasticsearch.storageClass')

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
    "ingress-nginx ingress-nginx-defaultbackend"
    "monitoring prometheus-operator-operator"
    "monitoring prometheus-operator-grafana"
    "monitoring prometheus-operator-kube-state-metrics"
    "monitoring blackbox-prometheus-blackbox-exporter"
    "fluentd fluentd-aggregator"
    "velero velero"
    "elastic-system elasticsearch-exporter"
    "elastic-system opendistro-es-client"
    "elastic-system opendistro-es-kibana"
)
if [ "$cloud_provider" == "exoscale" ]
then
    deployments+=("kube-system nfs-client-provisioner")
fi
if [ "$enable_harbor" == true ]; then
    deployments+=(
        "harbor harbor-harbor-chartmuseum"
        "harbor harbor-harbor-clair"
        "harbor harbor-harbor-core"
        "harbor harbor-harbor-jobservice"
        "harbor harbor-harbor-notary-server"
        "harbor harbor-harbor-notary-signer"
        "harbor harbor-harbor-portal"
        "harbor harbor-harbor-registry"
    )
fi
if [ "$enable_ck8sdash" == true ]; then
    deployments+=("ck8sdash ck8sdash")
fi
if [ "$enable_user_grafana" == true ]; then
    deployments+=("monitoring user-grafana")
fi
resourceKind="Deployment"
# Get json data in a smaller dataset
simpleData="$(getStatus $resourceKind)"
for deployment in "${deployments[@]}"
do
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
    "monitoring prometheus-operator-prometheus-node-exporter"
    "fluentd fluentd"
    "velero restic"
)
if [ "$storage_class" = local-storage ] || \
    [ "$elasticsearch_storage_class" = local-storage ]; then
  daemonsets+=("kube-system local-volume-provisioner")
fi

resourceKind="DaemonSet"
# Get json data in a smaller dataset
simpleData="$(getStatus $resourceKind)"
for daemonset in "${daemonsets[@]}"
do
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
    "monitoring prometheus-prometheus-operator-prometheus"
    "monitoring prometheus-wc-scraper-prometheus-instance"
    "monitoring alertmanager-prometheus-operator-alertmanager"
    "influxdb-prometheus influxdb"
    "elastic-system opendistro-es-data"
    "elastic-system opendistro-es-master"
)
if [ "$enable_harbor" == true ]; then
    statefulsets+=(
        "harbor harbor-harbor-database"
        "harbor harbor-harbor-redis"
    )
fi

resourceKind="StatefulSet"
# Get json data in a smaller dataset
simpleData="$(getStatus $resourceKind)"
for statefulset in "${statefulsets[@]}"
do
    read -r -a arr <<< "$statefulset"
    namespace="${arr[0]}"
    name="${arr[1]}"
    testResourceExistenceFast ${resourceKind} "${namespace}" "${name}" "${simpleData}"
done

# Format:
# namespace job-name timeout
jobs=(
    "elastic-system opendistro-es-configurer 120s"
)
if [ "$enable_harbor" == true ]; then
    jobs+=(
        "harbor init-harbor-job 120s"
    )
fi

echo
echo
echo "Testing jobs"
echo "===================="

for job in "${jobs[@]}"
do
    read -r -a arr <<< "$job"
    namespace="${arr[0]}"
    name="${arr[1]}"
    timeout="${arr[2]}"
    echo -n -e "\n${name}\t"
    if testResourceExistence job "${namespace}" "${name}"
    then
        testJobStatus "${namespace}" "${name}" "${timeout}"
    fi
done

# Format:
# namespace cronjob-name timeout
# influxdb cronjob is create by <template name>-metrics-retention-cronjob-<sc/wc>
# If the template name changes this has to be changed aswell.
cronjobs=(
  "influxdb-prometheus influxdb-metrics-retention-cronjob-sc"
  "influxdb-prometheus influxdb-metrics-retention-cronjob-wc"
  "influxdb-prometheus influxdb-backup"
  "elastic-system opendistro-es-curator"
  "elastic-system elasticsearch-slm"
  "elastic-system elasticsearch-backup"
)

echo
echo
echo "Testing cronjobs"
echo "===================="

for cronjob in "${cronjobs[@]}"
do
    read -r -a arr <<< "$cronjob"
    namespace="${arr[0]}"
    name="${arr[1]}"
    echo -n -e "\n${name}\t"
    if testResourceExistence cronjob "${namespace}" "${name}"
    then
        logCronJob "${namespace}" "${name}"
    fi
done
