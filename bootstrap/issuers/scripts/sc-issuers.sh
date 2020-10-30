#!/usr/bin/env bash

set -euo pipefail

echo "Preparing cert manager and creating Issuers" >&2
# shellcheck disable=SC1090
source "${common_path:?Missing common path}"
: "${config[config_file_sc]:?Missing service cluster config file}"
: "${issuers_path:?Missing issuers path}"
ck8sdash=$(yq r -e "${config[config_file_sc]}" 'ck8sdash.enabled')
harbor=$(yq r -e "${config[config_file_sc]}" 'harbor.enabled')

issuer_namespaces='dex elastic-system kube-system monitoring'
[ "$ck8sdash" = "true" ] && issuer_namespaces+=" ck8sdash"
[ "$harbor" = "true" ] && issuer_namespaces+=" harbor"
for ns in $issuer_namespaces
do
  helmfile -f "${issuers_path}/helmfile/helmfile.yaml" \
    -e service_cluster -n "${ns}" apply --suppress-diff
done
