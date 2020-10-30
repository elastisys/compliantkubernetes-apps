#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config=${CK8S_CONFIG_PATH}/sc-config.yaml

yq w -i "$sc_config" 'elasticsearch.extraRoleMappings' '[]'
