#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"

move_value_to() {
    length_root=$(yq4 "$1 | length" "$3")
    length_internal=$(yq4 "$2 | length" "$3")

    if [[ "${length_root}" -eq 0 ]]; then
        echo "$1 missing from $3, skipping."
    elif [[ "${length_internal}" -eq 0 ]]; then
        echo "moving .redis variables under .redis.internal"
        # shellcheck disable=SC2016
        yq4 -i ''"$1"' as $value | '"$2"' = $value' "$3"
    else
        echo "$1 was already migrated, skipping."
    fi
}

delete_value() {
    length=$(yq4 "$1 | length" "$2")

    if [[ "${length}" -eq 0 ]]; then
        echo "$1 missing from $2, skipping."
    else
        echo "deleting $1"
        yq4 -i "del($1)" "$2"
    fi
}

if [[ ! -f "$sc_config" ]]; then
  echo "$sc_config does not exist, skipping."
else
  move_value_to '.harbor.redis' '.harbor.redis.internal' "$sc_config"
  delete_value '.harbor.redis.persistentVolumeClaim' "$sc_config"
  delete_value '.harbor.redis.resources' "$sc_config"
fi
