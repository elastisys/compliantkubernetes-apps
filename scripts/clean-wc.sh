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
"${here}/.././bin/ck8s" ops kubectl wc delete ns falco fluentd gatekeeper gatekeeper-system ingress-nginx monitoring velero

# Destroy cert-manager helm release
"${here}/.././bin/ck8s" ops helmfile wc -l app=cert-manager destroy

# Clean up cert-manager namespace
"${here}/.././bin/ck8s" ops kubectl wc delete ns cert-manager

# Remove any lingering persistent volumes
"${here}/.././bin/ck8s" ops kubectl wc delete pv --all

# Remove all added custom resource definitions
"${here}/.././bin/ck8s" ops kubectl wc delete -f bootstrap/crds/ --recursive
