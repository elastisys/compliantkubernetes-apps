#!/usr/bin/bash

set -euo pipefail

IFS=$'\n'

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_defaults="${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"
sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
wc_defaults="${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"
wc_config="${CK8S_CONFIG_PATH}/wc-config.yaml"

if [[ ! -f "${sc_defaults}" ]]; then
    echo "Default sc-config does not exist, aborting."
    exit 1
elif [[ ! -f "${sc_config}" ]]; then
    echo "Override sc-config does not exist, aborting."
    exit 1
elif [[ ! -f "${wc_defaults}" ]]; then
    echo "Default wc-config does not exist, aborting."
    exit 1
elif [[ ! -f "${wc_config}" ]]; then
    echo "Override wc-config does not exist, aborting."
    exit 1
fi

sc_merged=$(yq m -x -a overwrite -j "${sc_defaults}" "${sc_config}")
wc_merged=$(yq m -x -a overwrite -j "${wc_defaults}" "${wc_config}")

sc_os=$(yq r -P -pp "${sc_config}" 'elasticsearch.**' | sed -r "s/\.\[.*\].*//" | uniq)
wc_os=$(yq r -P -pp "${wc_config}" 'elasticsearch.**' | sed -r "s/\.\[.*\].*//" | uniq)

sc_osd=$(yq r -P -pp "${sc_config}" 'kibana.**' | sed -r "s/\.\[.*\].*//" | uniq)

# Saving these for later migration steps, so they will survive init.
yq w "${sc_config}" -i -P "objectStorage.buckets.elasticsearch" "$(echo "${sc_merged}" | yq r - "objectStorage.buckets.elasticsearch")"
yq w "${sc_config}" -i -P "elasticsearch.snapshot.enabled" "$(echo "${sc_merged}" | yq r - "elasticsearch.snapshot.enabled")"
yq w "${sc_config}" -i -P "elasticsearch.snapshotRepository" "$(echo "${sc_merged}" | yq r - "elasticsearch.snapshotRepository")"

echo "sc-config.yaml: elasticsearch.* -> opensearch.*"
for kv in $sc_os; do
  kvt=$(echo "${kv}" | \
    sed -r "s/^elasticsearch\./opensearch\./" | \
    sed -r "s/\.subject_key$/\.subjectKey/" | \
    sed -r "s/\.roles_key$/\.rolesKey/" | \
    sed -r "s/\.snapshotRepository$/\.snapshot\.repository/")
  yq r "${sc_config}" "${kv}" -j | yq p - "${kvt}" -j | yq m "${sc_config}" - -i -x -a overwrite -P
done
yq w "${sc_config}" -i -P "opensearch.subdomain" "opensearch"
yq w "${sc_config}" -i -P "opensearch.clusterName" "opensearch"
yq w "${sc_config}" -i -P "opensearch.snapshot.repository" "opensearch-snapshots"
yq w "${sc_config}" -i -P "opensearch.createIndices" "true"
yq w "${sc_config}" -i -P "externalTrafficPolicy.whitelistRange.opensearch" "$(echo "${sc_merged}" | yq r - "externalTrafficPolicy.whitelistRange.elasticsearch")"
if [[ $(yq r "${sc_config}" "opensearch.masterNode.storageClass") == "{}" ]]; then
  yq w "${sc_config}" -i -P "opensearch.masterNode.storageClass" "null"
fi
if [[ $(yq r "${sc_config}" "opensearch.dataNode.storageClass") == "{}" ]]; then
  yq w "${sc_config}" -i -P "opensearch.dataNode.storageClass" "null"
fi

echo "wc-config.yaml: elasticsearch.* -> opensearch.*"
for kv in $wc_os; do
  kvt=$(echo "${kv}" | sed -r "s/^elasticsearch\./opensearch\./")
  echo "${wc_merged}" | yq r - "${kv}" -j | yq p - "${kvt}" -j | yq m "${wc_config}" - -i -x -a overwrite -P
done
yq w "${wc_config}" -i -P "opensearch.subdomain" "opensearch"

echo "sc-config.yaml: kibana.* -> opensearch.dashboards.*"
for kv in $sc_osd; do
  kvt=$(echo "${kv}" | sed -r "s/^kibana\./opensearch.dashboards\./")
  echo "${sc_merged}" | yq r - "${kv}" -j | yq p - "${kvt}" -j | yq m "${sc_config}" - -i -x -a overwrite -P
done
yq w "${sc_config}" -i -P "opensearch.dashboards.subdomain" "opensearch"

echo "Done"
