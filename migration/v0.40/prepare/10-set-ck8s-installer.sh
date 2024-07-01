#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

cluster="${CK8S_CLUSTER}"
if [[ "${CK8S_CLUSTER}" == both ]]; then
  cluster="wc"
fi

default_common_config="${CK8S_CONFIG_PATH}/defaults/common-config.yaml"

# check if kubespray directory exists
if [[ -d "${CK8S_CONFIG_PATH}/${cluster}-config" ]]; then
  yq4 -i '.global.ck8sK8sInstaller = "kubespray"' "${default_common_config}"
else
  yq4 -i '.global.ck8sK8sInstaller = "capi"' "${default_common_config}"
fi
