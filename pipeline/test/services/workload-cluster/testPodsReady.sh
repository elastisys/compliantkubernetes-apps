#!/bin/bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC1090
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

enable_falco_alerts=$(yq r -e "${CONFIG_FILE}" 'falco.alerts.enabled')
enable_falco=$(yq r -e "${CONFIG_FILE}" 'falco.enabled')
enable_opa=$(yq r -e "${CONFIG_FILE}" 'opa.enabled')
enable_user_alertmanager=$(yq r -e "${CONFIG_FILE}" 'user.alertmanager.enabled')
enable_velero=$(yq r -e "${CONFIG_FILE}" 'velero.enabled')
enable_local_pv_provisioner=$(yq r -e "${CONFIG_FILE}" 'storageClasses.local.enabled')
enable_nfs_provisioner=$(yq r -e "${CONFIG_FILE}" 'storageClasses.nfs.enabled')

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
    "ingress-nginx ingress-nginx-defaultbackend"
    "monitoring kube-prometheus-stack-operator"
    "monitoring kube-prometheus-stack-kube-state-metrics"
)
if "${enable_nfs_provisioner}"; then
    deployments+=("kube-system nfs-client-provisioner")
fi
if "{$enable_opa}"; then
    deployments+=("gatekeeper-system gatekeeper-controller-manager")
fi
if "${enable_falco_alerts}"; then
    deployments+=("falco falcosidekick")
fi
if "${enable_velero}"; then
    deployments+=("velero velero")
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
    "fluentd fluentd-fluentd-elasticsearch"
    "kube-system calico-node"
    "kube-system fluentd-system-fluentd-elasticsearch"
    "kube-system node-local-dns"
    "ingress-nginx ingress-nginx-controller"
    "monitoring kube-prometheus-stack-prometheus-node-exporter"
    "velero restic"
)
if "${enable_falco}"; then
    daemonsets+=("falco falco")
fi
if "${enable_velero}"; then
    daemonsets+=("velero restic")
fi
if "${enable_local_pv_provisioner}"; then
  daemonsets+=("kube-system local-volume-provisioner")
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
)

if "${enable_user_alertmanager}"; then
    statefulsets+=("monitoring alertmanager-alertmanager")
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
