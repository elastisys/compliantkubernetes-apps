#!/bin/bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC1090
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

cloud_provider=$(yq r -e "${CONFIG_FILE}" 'global.cloudProvider')
enable_ck8sdash=$(yq r -e "${CONFIG_FILE}" 'ck8sdash.enabled')
enable_falco_alerts=$(yq r -e "${CONFIG_FILE}" 'falco.alerts.enabled')
enable_falco=$(yq r -e "${CONFIG_FILE}" 'falco.enabled')
enable_opa=$(yq r -e "${CONFIG_FILE}" 'opa.enabled')
enable_user_alertmanager=$(yq r -e "${CONFIG_FILE}" 'user.alertmanager.enabled')

echo
echo
echo "Testing deployments"
echo "==================="

deployments=(
    "cert-manager cert-manager"
    "cert-manager cert-manager-cainjector"
    "cert-manager cert-manager-webhook"
    "kube-system coredns"
    "kube-system metrics-server"
    "kube-system calico-kube-controllers"
    "nginx-ingress nginx-ingress-default-backend"
    "monitoring prometheus-operator-operator"
    "monitoring prometheus-operator-kube-state-metrics"
    "velero velero"
)
if [ "$cloud_provider" == "exoscale" ]; then
    deployments+=("kube-system nfs-client-provisioner")
fi
if [ "$enable_ck8sdash" == true ]; then
    deployments+=("ck8sdash ck8sdash")
fi
if [ "$enable_opa" == true ]; then
    deployments+=("gatekeeper-system gatekeeper-controller-manager")
fi
if [ "$enable_falco_alerts" == true ]; then
    deployments+=("falco falcosidekick")
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
    "fluentd fluentd-fluentd-elasticsearch"
    "kube-system calico-node"
    "kube-system fluentd-system-fluentd-elasticsearch"
    "kube-system node-local-dns"
    "nginx-ingress nginx-ingress-controller"
    "monitoring prometheus-operator-prometheus-node-exporter"
    "velero restic"
)
if [ "$enable_falco" == true ]; then
    daemonsets+=("falco falco")
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
)

if [[ $enable_user_alertmanager == "true" ]]
then
    statefulsets+=("monitoring alertmanager-alertmanager")
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
