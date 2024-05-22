#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

common_config="${CK8S_CONFIG_PATH}/common-config.yaml"

delete_value() {
    length=$(yq r "$2" --length "$1")
    length_prom=$(yq r "$2" --length "prometheus")

    if [[ -z "${length}" ]]; then
        echo "$1 missing from $2, skipping."
    elif [[ "${length}" ]] && [[ "${length_prom}" -ge 2 ]]; then
        echo ".prometheus contains multiple configs. removing only $1."
        yq d -i "$2" "$1"
    elif [[ "${length}" ]] && [[ "${length_prom}" -eq 1 ]]; then
        echo "predictLinear is the only config under .prometheus. removing .prometheus from the config."
        yq d -i "$2" "prometheus"
    fi
}

for i in ${common_config}
do
  if [[ ! -f "$i" ]]; then
    echo "$i does not exist, skipping."
  else
    delete_value 'prometheus.predictLinear' "$i"
  fi
done
