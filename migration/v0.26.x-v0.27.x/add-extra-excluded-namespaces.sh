#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"

add_values_to() {
    echo "adding additional services namespaces to $1 in $3"
    yq4 -i "$1 = $2" "$3"
}

if [[ ! -f "$wc_config" ]]; then
    echo "$wc_config does not exist, skipping."
else
   add_values_to '.velero.excludedExtraNamespaces' '["postgres-system","rabbitmq-system","redis-system","argocd-system","jaeger-system"]' "$wc_config"
   add_values_to '.hnc.excludedExtraNamespaces' '["postgres-system","rabbitmq-system","redis-system","argocd-system","jaeger-system"]' "$wc_config"
fi
