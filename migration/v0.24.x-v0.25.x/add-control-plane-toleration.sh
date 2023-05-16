#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

common_config="${CK8S_CONFIG_PATH}/common-config.yaml"
sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"

add_toleration() {
    echo "Adding control-plane toleration in $i."
    yq4 -i '((.. | select(key == "tolerations") | (select(tag == "!!seq" and contains([{"key": "'"$1"'"}]) and contains([{"key": "'"$2"'"}]) == false))) += [{"key": "'"$2"'", "operator": "Exists", "effect": "NoSchedule"}])' "$3"
}

add_affinity() {
    echo "Replace master affinity label with control-plane in $i."
    yq4 -i '((.. | select(key == "matchExpressions") | select(tag == "!!seq" and contains([{"key": "'"$1"'"}]))) = [{"key": "'"$2"'", "operator": "Exists"}])' "$3"
}

for i in ${sc_config} ${wc_config} ${common_config}; do
  if [[ ! -f "$i" ]]; then
    echo "$i does not exist, skipping."
    exit 1
  else
    add_toleration 'node-role.kubernetes.io/master' 'node-role.kubernetes.io/control-plane' "$i"
    add_affinity 'node-role.kubernetes.io/master' 'node-role.kubernetes.io/control-plane' "$i"
  fi
done
