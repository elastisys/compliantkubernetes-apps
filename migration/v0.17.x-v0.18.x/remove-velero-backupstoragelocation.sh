#!/bin/bash

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config_default="${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"
sc_config_override="${CK8S_CONFIG_PATH}/sc-config.yaml"
sc_config="yq merge ${sc_config_default} ${sc_config_override} --overwrite --arrays overwrite"

wc_config_default="${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"
wc_config_override="${CK8S_CONFIG_PATH}/wc-config.yaml"
wc_config="yq merge ${wc_config_default} ${wc_config_override} --overwrite --arrays overwrite"

OBJECT_STORAGE_TYPE_SC=$(yq r <(${sc_config}) objectStorage.type)
if [[ ${OBJECT_STORAGE_TYPE_SC} == "s3" ]]; then
  STORAGE_TYPE_SC="aws"
elif [[ ${OBJECT_STORAGE_TYPE_SC} == "gcs" ]]; then
  STORAGE_TYPE_SC="gcs"
else
  echo "Skipped deletion of backupstoragelocation because the type was set to ${OBJECT_STORAGE_TYPE_SC}"
  exit 0
fi
"${here}/../../bin/ck8s" ops kubectl sc delete backupstoragelocation -n velero $STORAGE_TYPE_SC
OBJECT_STORAGE_TYPE_WC=$(yq r <(${wc_config}) objectStorage.type)
if [[ ${OBJECT_STORAGE_TYPE_WC} == "s3" ]]; then
  STORAGE_TYPE_WC="aws"
elif [[ ${OBJECT_STORAGE_TYPE_WC} == "gcs" ]]; then
  STORAGE_TYPE_WC="gcs"
else
  echo "Skipped deletion of backupstoragelocation because the type was set to ${OBJECT_STORAGE_TYPE_WC}"
  exit 0
fi
"${here}/../../bin/ck8s" ops kubectl wc delete backupstoragelocation -n velero $STORAGE_TYPE_WC
