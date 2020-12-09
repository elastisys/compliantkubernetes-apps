#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

for cluster in sc wc; do
  config="${CK8S_CONFIG_PATH}/${cluster}-config.yaml"

  s3_region=$(yq r "$config" 's3.region')
  s3_region_address=$(yq r "$config" 's3.regionAddress')
  s3_region_endpoint=$(yq r "$config" 's3.regionEndpoint')

  buckets_harbor=$(yq r "$config" 's3.buckets.harbor')
  buckets_velero=$(yq r "$config" 's3.buckets.velero')
  buckets_elasticsearch=$(yq r "$config" 's3.buckets.elasticsearch')
  buckets_influxDB=$(yq r "$config" 's3.buckets.influxDB')
  buckets_scFluentd=$(yq r "$config" 's3.buckets.scFluentd')

  yq w -i "$config" 'objectStorage.type' "s3"

  yq w -i "$config" 'objectStorage.s3.region' "${s3_region}"
  yq w -i "$config" 'objectStorage.s3.regionAddress' "${s3_region_address}"
  yq w -i "$config" 'objectStorage.s3.regionEndpoint' "${s3_region_endpoint}"

  yq w -i "$config" 'objectStorage.buckets.harbor' "${buckets_harbor}"
  yq w -i "$config" 'objectStorage.buckets.velero' "${buckets_velero}"
  yq w -i "$config" 'objectStorage.buckets.elasticsearch' "${buckets_elasticsearch}"
  yq w -i "$config" 'objectStorage.buckets.influxDB' "${buckets_influxDB}"
  yq w -i "$config" 'objectStorage.buckets.scFluentd' "${buckets_scFluentd}"

  yq d -i "$config" 's3'
done

secret="${CK8S_CONFIG_PATH}/secrets.yaml"
secret_tmp="${CK8S_CONFIG_PATH}/secrets_tmp.yaml"
sops_conf="${CK8S_CONFIG_PATH}/.sops.yaml"

s3_access_key=$(sops -d --extract '["s3"]["accessKey"]' "${secret}")
s3_secret_key=$(sops -d --extract '["s3"]["secretKey"]' "${secret}")

sops -d "${secret}" | \
  yq w - 'objectStorage.s3.accessKey' "${s3_access_key}" | \
  yq w - 'objectStorage.s3.secretKey' "${s3_secret_key}" | \
  yq d - 's3' | \
  sops --config "${sops_conf}" --input-type=yaml -e /dev/stdin > "${secret_tmp}"
mv "${secret_tmp}" "${secret}"
