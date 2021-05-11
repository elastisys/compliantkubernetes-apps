#!/bin/bash

echo "WARNING:"
echo "This script will remove compliant kubernetes apps from your workload cluster."
echo "It will also remove any user namespaces managed by compliant kubernetes apps."
echo -n "Do you want to continue (y/N): "
read -r reply
if [[ ${reply} != "y" ]]; then
    exit 1
fi

here="$(dirname "$(readlink -f "$0")")"

# Destroy user namespaces before everything else,
# to avoid race conditions where CRs are not deleted before controllers in other namespaces
"${here}/.././bin/ck8s" ops helmfile wc -l app=user-rbac destroy

# Destroy all helm releases
"${here}/.././bin/ck8s" ops helmfile wc -l app!=cert-manager destroy

# Clean up namespaces and any other resources left behind by the apps
"${here}/.././bin/ck8s" ops kubectl wc delete ns falco fluentd gatekeeper-system ingress-nginx monitoring velero

# Destroy cert-manager helm release
"${here}/.././bin/ck8s" ops helmfile wc -l app=cert-manager destroy

# Clean up cert-manager namespace
"${here}/.././bin/ck8s" ops kubectl wc delete ns cert-manager

# Remove any lingering persistent volumes
"${here}/.././bin/ck8s" ops kubectl wc delete pv --all

# Velero-specific removal: https://velero.io/docs/v1.5/uninstalling/
"${here}/.././bin/ck8s" ops kubectl wc delete namespace/velero clusterrolebinding/velero
"${here}/.././bin/ck8s" ops kubectl wc delete crds -l component=velero
"${here}/.././bin/ck8s" ops kubectl wc delete crds -l app.kubernetes.io/name=velero

# Cert-manager specific removal
"${here}/.././bin/ck8s" ops kubectl wc delete namespace cert-manager
"${here}/.././bin/ck8s" ops kubectl wc delete crds -l app.kubernetes.io/name=cert-manager

# Dex specific removal
# Keep for now, we won't use Dex CRDs in the future
"${here}/.././bin/ck8s" ops kubectl wc delete crds \
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
        kubectl wc api-resources \
        --api-group=monitoring.coreos.com \
        -o name
    )
if [ -n "$PROM_CRDS" ]; then
    "${here}/.././bin/ck8s" ops kubectl wc delete crds $PROM_CRDS
fi
