#!/usr/bin/env bash

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

echo "WARNING:"
echo "This script will remove compliant kubernetes apps from your workload cluster."
echo "It will also remove any user namespaces managed by compliant kubernetes apps."
echo -e "Your current \u1b[33mCK8S_CONFIG_PATH\033[m is set to: \u1b[33;4m${CK8S_CONFIG_PATH}\033[m"
echo -n "Do you want to continue (y/N): "
read -r reply
if [[ ${reply} != "y" ]]; then
  exit 1
fi

here="$(dirname "$(readlink -f "$0")")"

# shellcheck source=bin/common.bash
source "${here}/../bin/common.bash"

config_load wc

clusterAPIEnabled=$(yq '.clusterApi.enabled' "${config[config_file_wc]}")

GATE_VALWEBHOOK=$(
  "${here}/.././bin/ck8s" ops \
    kubectl wc get \
    validatingwebhookconfigurations \
    -l gatekeeper.sh/system=yes \
    -oname
)

if [ -n "${GATE_VALWEBHOOK}" ]; then
  # Destroy gatekeeper validatingwebhook which could potentially prevent other resources from being deleted
  "${here}/.././bin/ck8s" ops kubectl wc delete "${GATE_VALWEBHOOK}"
fi

# Destroy user subnamespaces before their parent namespaces,
# this might fail if there are multiple levels.
"${here}/.././bin/ck8s" ops kubectl wc delete subns -A --all

# Destroy user namespaces before everything else,
# to avoid race conditions where CRs are not deleted before controllers in other namespaces
"${here}/.././bin/ck8s" ops helmfile wc -l app=dev-rbac destroy

# Might fail to be destroyed the first time, therefore run it once now
"${here}/.././bin/ck8s" ops helmfile wc -l app=hnc destroy

# Makes sure to uninstall Velero properly: https://velero.io/docs/v1.13/uninstalling/
"${here}/.././bin/ck8s" ops velero wc uninstall

# Destroy all helm releases
"${here}/.././bin/ck8s" ops helmfile wc -l app!=cert-manager -l app!=admin-rbac destroy

# Clean up namespaces and any other resources left behind by the apps
"${here}/.././bin/ck8s" ops kubectl wc delete ns alertmanager falco fluentd-system fluentd gatekeeper-system gpu-operator hnc-system ingress-nginx monitoring velero kured

# Clean up any leftover challenges
mapfile -t CHALLENGES < <(
  "${here}/.././bin/ck8s" ops kubectl wc get challenge -A -oyaml |
    yq '.items[] | .metadata.name + "," + .metadata.namespace'
)
for challenge in "${CHALLENGES[@]}"; do
  IFS=, read -r name namespace <<<"${challenge}"
  "${here}/.././bin/ck8s" ops \
    kubectl wc patch challenge "${name}" -n "${namespace}" \
    -p '{"metadata":{"finalizers":null}}' --type=merge
done

if [ "${clusterAPIEnabled}" = "false" ]; then
  # Destroy cert-manager helm release
  "${here}/.././bin/ck8s" ops helmfile wc -l app=cert-manager destroy
else
  log_info "Cluster API provisioned cluster, skipping deletion of cert-manager Helm release"
fi

if [[ -f "${CK8S_CONFIG_PATH}/cluster-index.yaml" ]]; then
  # Destroy local-cluster minio release, otherwise pvc cleanup will get stuck
  helmfile -e local_cluster -f "${here}/../helmfile.d" -l app=minio destroy
fi

# Remove any lingering persistent volume claims
"${here}/.././bin/ck8s" ops kubectl wc delete pvc -A --all

# Velero-specific removal: https://velero.io/docs/v1.10/uninstalling/
"${here}/.././bin/ck8s" ops kubectl wc delete crds -l component=velero

if [ "${clusterAPIEnabled}" = "false" ]; then
  # Cert-manager specific removal
  "${here}/.././bin/ck8s" ops kubectl wc delete namespace cert-manager
  #"${here}/.././bin/ck8s" ops kubectl wc delete crds -l app.kubernetes.io/name=cert-manager
else
  log_info "Cluster API provisioned cluster, skipping deletion of cert-manager namespace"
fi

# Delete kube prometheus stack CRDs
mapfile -t PROM_CRDS < <("${here}/.././bin/ck8s" ops kubectl wc api-resources --api-group=monitoring.coreos.com -o name)
if [[ "${#PROM_CRDS[@]}" -gt 0 ]]; then
  "${here}/.././bin/ck8s" ops kubectl wc delete crds "${PROM_CRDS[@]}"
fi

# Delete Trivy CRDs
mapfile -t TRIVY_CRDS < <("${here}/.././bin/ck8s" ops kubectl wc api-resources --api-group=aquasecurity.github.io -o name)
if [[ "${#TRIVY_CRDS[@]}" -gt 0 ]]; then
  "${here}/.././bin/ck8s" ops kubectl wc delete crds "${TRIVY_CRDS[@]}"
fi

# Delete Gatekeeper CRDs
GATE_CRDS=$("${here}/.././bin/ck8s" ops kubectl wc get crds -l gatekeeper.sh/system=yes -oname)
if [ -n "$GATE_CRDS" ]; then
  # shellcheck disable=SC2086
  "${here}/.././bin/ck8s" ops kubectl wc delete --ignore-not-found=true $GATE_CRDS
fi

GATE_CONS=$("${here}/.././bin/ck8s" ops kubectl wc get crds -l gatekeeper.sh/constraint=yes -oname)
if [ -n "$GATE_CONS" ]; then
  # shellcheck disable=SC2086
  "${here}/.././bin/ck8s" ops kubectl wc delete --ignore-not-found=true $GATE_CONS
fi

# Delete HNC CRDs
mapfile -t HNC_CRDS < <("${here}/.././bin/ck8s" ops kubectl wc api-resources --api-group=hnc.x-k8s.io -o name)
if [[ "${#HNC_CRDS[@]}" -gt 0 ]]; then
  "${here}/.././bin/ck8s" ops kubectl wc delete crds "${HNC_CRDS[@]}"
fi

"${here}/.././bin/ck8s" ops helmfile wc -l app=admin-rbac destroy
