#!/bin/bash

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

echo "WARNING:"
echo "This script will remove compliant kubernetes apps from your service cluster."
echo -e "Your current \u1b[33mCK8S_CONFIG_PATH\033[m is set to: \u1b[33;4m${CK8S_CONFIG_PATH}\033[m"
echo -n "Do you want to continue (y/N): "
read -r reply
if [[ ${reply} != "y" ]]; then
  exit 1
fi

here="$(dirname "$(readlink -f "$0")")"

# shellcheck source=bin/common.bash
source "${here}/../bin/common.bash"

config_load sc

clusterAPIEnabled=$(yq4 '.clusterApi.enabled' "${config[config_file_sc]}")

GATE_VALWEBHOOK=$(
    "${here}/.././bin/ck8s" ops \
        kubectl sc get \
        validatingwebhookconfigurations \
        -l gatekeeper.sh/system=yes \
        -oname
    )

if [ -n "${GATE_VALWEBHOOK}" ]; then
    # Destroy gatekeeper validatingwebhook which could potentially prevent other resources from being deleted
    "${here}/.././bin/ck8s" ops kubectl sc delete "${GATE_VALWEBHOOK}"
fi

# Destroy all helm releases
"${here}/.././bin/ck8s" ops helmfile sc -l app!=cert-manager destroy

# Clean up namespaces and any other resources left behind by the apps
"${here}/.././bin/ck8s" ops kubectl sc delete ns dex opensearch-system harbor fluentd-system gatekeeper-system thanos ingress-nginx monitoring kured falco velero

# Clean up any leftover challenges
mapfile -t CHALLENGES < <(
    "${here}/.././bin/ck8s" ops kubectl sc get challenge -A -oyaml | \
        yq4 '.items[] | .metadata.name + "," + .metadata.namespace'
    )
for challenge in "${CHALLENGES[@]}"; do
    IFS=, read -r name namespace <<< "${challenge}"
    "${here}/.././bin/ck8s" ops \
        kubectl sc patch challenge "${name}" -n "${namespace}" \
        -p '{"metadata":{"finalizers":null}}' --type=merge
done

if [ "${clusterAPIEnabled}" = "false" ]; then
  # Destroy cert-manager helm release
  "${here}/.././bin/ck8s" ops helmfile sc -l app=cert-manager destroy
else
  log_info "Cluster API provisioned cluster, skipping deletion of cert-manager Helm release"
fi

# Destroy local-cluster minio release, otherwise pvc cleanup will get stuck
helmfile -e local_cluster -f "${here}/../helmfile.d" -l app=minio destroy

# Remove any lingering persistent volume claims
"${here}/.././bin/ck8s" ops kubectl sc delete pvc -A --all

# Velero-specific removal: https://velero.io/docs/v1.10/uninstalling/
"${here}/.././bin/ck8s" ops kubectl sc delete crds -l component=velero

if [ "${clusterAPIEnabled}" = "false" ]; then
  # Cert-manager specific removal
  "${here}/.././bin/ck8s" ops kubectl sc delete namespace cert-manager
  "${here}/.././bin/ck8s" ops kubectl sc delete crds -l app.kubernetes.io/name=cert-manager
else
  log_info "Cluster API provisioned cluster, skipping deletion of cert-manager namespace and CRDs"
fi

# Dex specific removal
# Keep for now, we won't use Dex CRDs in the future
"${here}/.././bin/ck8s" ops kubectl sc delete crds \
    authcodes.dex.coreos.com \
    authrequests.dex.coreos.com \
    connectors.dex.coreos.com \
    oauth2clients.dex.coreos.com \
    offlinesessionses.dex.coreos.com \
    passwords.dex.coreos.com \
    refreshtokens.dex.coreos.com \
    signingkeies.dex.coreos.com \
    devicerequests.dex.coreos.com \
    devicetokens.dex.coreos.com

# Prometheus specific removal
PROM_CRDS=$(
    "${here}/.././bin/ck8s" ops \
        kubectl sc api-resources \
        --api-group=monitoring.coreos.com \
        -o name
    )
if [ -n "$PROM_CRDS" ]; then
    # shellcheck disable=SC2086
    # We definitely want word splitting here.
    "${here}/.././bin/ck8s" ops kubectl sc delete crds $PROM_CRDS
fi

# Trivy specific removal
TRIVY_CRDS=$(
    "${here}/.././bin/ck8s" ops \
        kubectl sc api-resources \
        --api-group=aquasecurity.github.io \
        -o name
    )

# Delete CRDs
if [ -n "$TRIVY_CRDS" ]; then
    # shellcheck disable=SC2086
    # We definitely want word splitting here.
    "${here}/.././bin/ck8s" ops kubectl sc delete crds $TRIVY_CRDS
fi

# Delete Gatekeeper CRDs
GATE_CRDS=$("${here}/.././bin/ck8s" ops kubectl sc get crds -l gatekeeper.sh/system=yes -oname)
if [ -n "$GATE_CRDS" ]; then
    # shellcheck disable=SC2086
    "${here}/.././bin/ck8s" ops kubectl sc delete --ignore-not-found=true $GATE_CRDS
fi

GATE_CONS=$("${here}/.././bin/ck8s" ops kubectl sc get crds -l gatekeeper.sh/constraint=yes -oname)
if [ -n "$GATE_CONS" ]; then
    # shellcheck disable=SC2086
    "${here}/.././bin/ck8s" ops kubectl sc delete --ignore-not-found=true $GATE_CONS
fi
