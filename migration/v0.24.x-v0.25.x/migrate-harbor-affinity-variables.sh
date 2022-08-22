#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"

move_value_to() {
    value=$(yq4 "${1}" "${3}")

    if [[ -z "${value}" ]]; then
        echo "${1} missing from ${3}, skipping."
    else
        yq4 "${1}" "${3}" | yq4 "${2}" - | yq4 eval-all -i 'select(fi == 0) * select(fi == 1)' "${3}" -
    fi
}

delete_value() {
    value=$(yq4 "${1}" "${2}")

    if [[ -z "${value}" ]]; then
        echo "$1 missing from $2, skipping."
    else
        yq4 "del(${1})" -i "$2"
    fi
}

if [[ "$(yq4 '.harbor.affinity' "${sc_config}")" != "null" ]]; then
  move_value_to '.harbor.affinity' '{"harbor":{"chartmuseum":{"affinity":.}}}' "${sc_config}"
  move_value_to '.harbor.affinity' '{"harbor":{"core":{"affinity":.}}}' "${sc_config}"
  move_value_to '.harbor.affinity' '{"harbor":{"jobservice":{"affinity":.}}}' "${sc_config}"
  move_value_to '.harbor.affinity' '{"harbor":{"notary":{"affinity":.}}}' "${sc_config}"
  move_value_to '.harbor.affinity' '{"harbor":{"notarySigner":{"affinity":.}}}' "${sc_config}"
  move_value_to '.harbor.affinity' '{"harbor":{"portal":{"affinity":.}}}' "${sc_config}"
  move_value_to '.harbor.affinity' '{"harbor":{"registry":{"affinity":.}}}' "${sc_config}"
  if [[ "$(yq4 '.harbor.database.type' "${sc_config}")" == "internal" ]]; then
    move_value_to '.harbor.affinity' '{"harbor":{"database":{"internal":{"affinity":.}}}}' "${sc_config}"
  fi
  if [[ "$(yq4 '.harbor.redis.type' "${sc_config}")" == "internal" ]]; then
    move_value_to '.harbor.affinity' '{"harbor":{"redis":{"internal":{"affinity":.}}}}' "${sc_config}"
  fi
  delete_value '.harbor.affinity' "${sc_config}"
fi
