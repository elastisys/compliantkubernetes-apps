#!/usr/bin/env bash

set -euo pipefail

environment=$1
# shellcheck disable=SC1090
source "${common_path:?Missing common path}"
# shellcheck disable=SC1090
source "${storageclass_path:?Missing storageclass path}/scripts/install-storage-class-provider.sh"

case ${environment} in
    service_cluster)
        config_file="${config["config_file_sc"]:?Missing service cluster config}"
        elasticStorageClass=$(yq r -e "${config_file}" 'elasticsearch.dataNode.storageClass')
        ;;
    workload_cluster)
        config_file="${config["config_file_wc"]:?Missing workload cluster config}"
        ;;
esac
storageClass=$(yq r -e "${config_file}" 'global.storageClass')

install_storage_class_provider "${storageClass}" "${environment}"
if [ "${environment}" = service_cluster ]; then
    install_storage_class_provider "${elasticStorageClass}" service_cluster
fi
