#!/usr/bin/env bash

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

retention=$(yq r "${CK8S_CONFIG_PATH}"/sc-config.yaml opensearch.curator.retention -e 2>&1)

[ "${?}" = "1" ] && echo "No migration needed" && exit 0

echo -e "Retention settings:\n$retention"

base="
- command: update
  path: opensearch.curator.retention
  value:"

for alias in other kubeAudit kubernetes authLog; do
  size=$(yq r "${CK8S_CONFIG_PATH}"/sc-config.yaml "opensearch.curator.retention.${alias}SizeGB")
  age=$(yq r "${CK8S_CONFIG_PATH}"/sc-config.yaml "opensearch.curator.retention.${alias}AgeDays")
  alias_lc=$(echo "${alias}" | awk '{print tolower($0)}')

  # Ensure at least one is set to add pattern
  [ -n "${size}" ] || [ -n "${age}" ] && base+="
    - pattern: ${alias_lc}-*"

  [ -n "${size}" ] && base+="
      sizeGB: ${size}"

  [ -n "${age}" ] && base+="
      ageDays: ${age}"
done

overlay="- command: update
  path: opensearch.curator.retention
  value:
$(yq r "${CK8S_CONFIG_PATH}"/defaults/sc-config.yaml "opensearch.curator.retention" | sed -e 's/^/    /')"

touch "${CK8S_CONFIG_PATH}/base.tmp.yaml"
touch "${CK8S_CONFIG_PATH}/overlay.tmp.yaml"

echo "${base}" | yq w -i -s - "${CK8S_CONFIG_PATH}/base.tmp.yaml"
echo "${overlay}" | yq w -i -s - "${CK8S_CONFIG_PATH}/overlay.tmp.yaml"

merged="
- command: update
  path: opensearch.curator.retention
  value:
$(yq m "${CK8S_CONFIG_PATH}/base.tmp.yaml" "${CK8S_CONFIG_PATH}/overlay.tmp.yaml" | yq r - opensearch.curator.retention | sed -e 's/^/    /')"

echo "${merged}" | yq w -i -s - "${CK8S_CONFIG_PATH}/sc-config.yaml"

rm "${CK8S_CONFIG_PATH}/base.tmp.yaml" "${CK8S_CONFIG_PATH}/overlay.tmp.yaml"
