#!/usr/bin/env bash

set -euo pipefail

echo "Preparing cert-manager and issuers" >&2
# shellcheck disable=SC1090
source "${common_path:?Missing common path}"
: "${config[config_file_wc]:?Missing workload cluster config file}"
: "${issuers_path:?Missing issuers path}"
ck8sdash=$(yq r -e "${config[config_file_wc]}" 'ck8sdash.enabled')

issuer_namespaces='kube-system monitoring'
[ "$ck8sdash" == "true" ] && issuer_namespaces+=" ck8sdash"
for ns in $issuer_namespaces
do
  helmfile -f "${issuers_path}/helmfile/helmfile.yaml" \
    -e workload_cluster -n "${ns}" apply --suppress-diff
done
