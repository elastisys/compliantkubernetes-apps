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

# Destroy all helm releases
"${here}/.././bin/ck8s" ops helmfile sc -l app!=cert-manager destroy

# Clean up namespaces and any other resources left behind by the apps
"${here}/.././bin/ck8s" ops kubectl sc delete ns dex opensearch-system harbor fluentd thanos ingress-nginx monitoring kured falco

# Clean up any leftover challenges
CHALLENGES=$(
    "${here}/.././bin/ck8s" ops \
      kubectl sc get challenge -A \
      "-o=jsonpath='{range .items[*]}{.metadata.name}{\",\"}{.metadata.namespace}{\"\n\"}{end}'"
	)
if [ -n "$CHALLENGES" ]; then
  for challenge in "${CHALLENGES[@]}"; do
      IFS=, read -r name namespace <<< "$challenge"
      "${here}/.././bin/ck8s" ops \
          kubectl sc patch challenge \
          "$name" -n "$namespace" \
          "-p '{\"metadata\":{\"finalizers\":null}}'" \
          --type=merge
  done
fi

# Destroy cert-manager helm release
"${here}/.././bin/ck8s" ops helmfile sc -l app=cert-manager destroy

# Clean up cert-manager namespace
"${here}/.././bin/ck8s" ops kubectl sc delete ns cert-manager

# Remove any lingering persistent volume claims
"${here}/.././bin/ck8s" ops kubectl sc delete pvc -A --all

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

# Trivy specific removal
TRIVY_CRDS=$(
    "${here}/.././bin/ck8s" ops \
        kubectl sc api-resources \
        --api-group=aquasecurity.github.io \
        -o name
    )

# Delete CRs
for cr in $TRIVY_CRDS; do
    "${here}/.././bin/ck8s" ops kubectl sc delete "$cr" --all --all-namespaces
done

# Delete CRDs
if [ -n "$TRIVY_CRDS" ]; then
    # shellcheck disable=SC2086
    # We definitely want word splitting here.
    "${here}/.././bin/ck8s" ops kubectl sc delete crds $TRIVY_CRDS
fi
