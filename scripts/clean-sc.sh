#!/bin/bash

echo "WARNING:"
echo "This script will remove compliant kubernetes apps from your service cluster."
echo -n "Do you want to continue (y/N): "
read -r reply
if [[ ${reply} != "y" ]]; then
    exit 1
fi

here="$(dirname "$(readlink -f "$0")")"

# Destroy all helm releases
"${here}/.././bin/ck8s" ops helmfile sc -l app!=cert-manager destroy

# Clean up namespaces and any other resources left behind by the apps
"${here}/.././bin/ck8s" ops kubectl sc delete ns dex opensearch-system harbor fluentd thanos influxdb-prometheus ingress-nginx monitoring velero

# Destroy cert-manager helm release
"${here}/.././bin/ck8s" ops helmfile sc -l app=cert-manager destroy

# Clean up cert-manager namespace
"${here}/.././bin/ck8s" ops kubectl sc delete ns cert-manager

# Remove any lingering persistent volumes
"${here}/.././bin/ck8s" ops kubectl sc delete pv --all

# Velero-specific removal: https://velero.io/docs/v1.5/uninstalling/
"${here}/.././bin/ck8s" ops kubectl sc delete namespace/velero clusterrolebinding/velero
"${here}/.././bin/ck8s" ops kubectl sc delete crds -l component=velero
"${here}/.././bin/ck8s" ops kubectl sc delete crds -l app.kubernetes.io/name=velero

# Cert-manager specific removal
"${here}/.././bin/ck8s" ops kubectl sc delete namespace cert-manager
"${here}/.././bin/ck8s" ops kubectl sc delete crds -l app.kubernetes.io/name=cert-manager

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
    signingkeies.dex.coreos.com

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
