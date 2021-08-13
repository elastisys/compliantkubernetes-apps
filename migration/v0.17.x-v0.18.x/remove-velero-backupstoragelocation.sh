#!/bin/bash

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

OBJECT_STORAGE_TYPE_SC=$(yq r "${CK8S_CONFIG_PATH}/sc-config.yaml" objectStorage.type)
if [[ ${OBJECT_STORAGE_TYPE_SC} == "s3" ]]; then
  STORAGE_TYPE_SC="aws"
elif [[ ${OBJECT_STORAGE_TYPE_SC} == "gcs" ]]; then
  STORAGE_TYPE_SC="gcs"
else
  echo "Skipped deletion of backupstoragelocation because the type was set to ${OBJECT_STORAGE_TYPE_SC}"
  exit 0
fi
"${here}/../../bin/ck8s" ops kubectl sc delete backupstoragelocation -n velero $STORAGE_TYPE_SC
OBJECT_STORAGE_TYPE_WC=$(yq r "${CK8S_CONFIG_PATH}/wc-config.yaml" objectStorage.type)
if [[ ${OBJECT_STORAGE_TYPE_WC} == "s3" ]]; then
  STORAGE_TYPE_WC="aws"
elif [[ ${OBJECT_STORAGE_TYPE_WC} == "gcs" ]]; then
  STORAGE_TYPE_WC="gcs"
else
  echo "Skipped deletion of backupstoragelocation because the type was set to ${OBJECT_STORAGE_TYPE_WC}"
  exit 0
fi
"${here}/../../bin/ck8s" ops kubectl wc delete backupstoragelocation -n velero $STORAGE_TYPE_WC
