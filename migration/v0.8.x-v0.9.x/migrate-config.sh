#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

for cluster in sc wc; do
  config="${CK8S_CONFIG_PATH}/${cluster}-config.yaml"

  environment_name=$(yq r "$config" 'global.environmentName')

  yq w -i "$config" 'global.clusterName' "${environment_name}-${cluster}"

  yq d -i "$config" 'global.environmentName'
done
