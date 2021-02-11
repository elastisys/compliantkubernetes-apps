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

config_file="$CK8S_CONFIG_PATH/${1}-config.yaml"
cloud_provider=$(yq r "${config_file}" 'global.cloudProvider')

function check_if_bucket_exists() { # arguments: bucket name
  local bucket_name="${1}"

  echo "Checking status of bucket [${bucket_name}] at [$cloud_provider]"

  if with_s3cfg "${secrets[s3cfg_file]}" "s3cmd --config {} ls s3://${bucket_name}" > /dev/null 2>&1; then
      echo "Bucket [${bucket_name}] exists at [${cloud_provider}]"
  else
      echo "Bucket [${bucket_name}] does not exist at [${cloud_provider}]" && exit 1
  fi
}

# shellcheck disable=SC2086
for bucket_name in $(yq r ${config_file} 'objectStorage.buckets.*'); do
  check_if_bucket_exists "${bucket_name}"
done
