#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

here="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1090
source "${here}/../../../bin/common.bash"
: "${secrets[s3cfg_file]:?Missing S3 config file}"

case ${1:-noarg} in
  sc|wc) : ;;
  *) echo "Usage: $(basename "$0") (sc|wc)" 1>&2; exit 1 ;;
esac
config_file="$CK8S_CONFIG_PATH/$1-config.yaml"
cloud_provider=$(yq r "$config_file" 'global.cloudProvider')

# In config:
# objectStorage.buckets.<bucket>
buckets=(
  harbor
  velero
  elasticsearch
  influxDB
  scFluentd
)

function check_if_bucket_exists() { # arguments: bucket name
  local bucket_name="$1"

  echo "Checking status of bucket [${bucket_name}] at [$cloud_provider]"
  bucket_exists=$(echo "$S3_BUCKET_LIST" | awk "\$3~/^s3:\/\/${bucket_name}$/ {print \$3}")

  if [ "$bucket_exists" ]; then
      echo "bucket [${bucket_name}] exists at [$cloud_provider]"
  else
      echo "bucket [${bucket_name}] does not exist at [$cloud_provider]"
      exit 1
  fi
}

# get a list of all the S3 buckets
S3_BUCKET_LIST=$(with_s3cfg "${secrets[s3cfg_file]}" "s3cmd --config {} ls")

for bucket in "${buckets[@]}"
do
  bucket_name=$(yq r "$config_file" "objectStorage.buckets.$bucket")
  check_if_bucket_exists "$bucket_name"
done
