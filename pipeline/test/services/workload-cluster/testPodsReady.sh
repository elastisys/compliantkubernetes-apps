#!/usr/bin/env bash

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=pipeline/test/services/funcs.sh
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

enable_falco_alerts=$(yq -e '.falco.alerts.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_falco=$(yq -e '.falco.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_hnc=$(yq -e '.hnc.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_hnc_ha=$(yq -e '.hnc.ha' "${CONFIG_FILE}" 2>/dev/null)
enable_user_alertmanager=$(yq -e '.user.alertmanager.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_velero=$(yq -e '.velero.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_kured=$(yq -e '.kured.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_fluentd=$(yq '.fluentd.enabled' "${CONFIG_FILE}" 2>/dev/null)
enable_fluentd_audit=$(yq '.fluentd.audit.enabled' "${CONFIG_FILE}" 2>/dev/null)

echo
echo
echo "Testing deployments"
echo "==================="

deployments=(
  "cert-manager cert-manager"
  "cert-manager cert-manager-cainjector"
  "cert-manager cert-manager-webhook"
  "gatekeeper-system gatekeeper-controller-manager"
  "ingress-nginx ingress-nginx-default-backend"
  "kube-system coredns"
  "kube-system metrics-server"
  "monitoring kube-prometheus-stack-operator"
  "monitoring kube-prometheus-stack-kube-state-metrics"
)
if "${enable_hnc}"; then
  deployments+=("hnc-system hnc-controller-controller-manager")

  if "${enable_hnc_ha}"; then
    deployments+=("hnc-system hnc-controller-webhook")
  fi
fi
if "${enable_falco}" && "${enable_falco_alerts}"; then
  deployments+=("falco falco-falcosidekick")
fi
if "${enable_velero}"; then
  deployments+=("velero velero")
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
if "${enable_falco}"; then
  daemonsets+=("falco falco")
fi
if "${enable_fluentd}"; then
  daemonsets+=(
    "fluentd fluentd-fluentd-elasticsearch"
    "fluentd-system fluentd-forwarder"
  )
fi
if "${enable_velero}"; then
  daemonsets+=("velero node-agent")
fi
if "${enable_kured}"; then
  daemonsets+=("kured kured")
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
)

if "${enable_user_alertmanager}"; then
  statefulsets+=("alertmanager alertmanager-alertmanager")
fi
if "${enable_fluentd}" && "${enable_fluentd_audit}"; then
  statefulsets+=("fluentd-system fluentd-aggregator")
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
