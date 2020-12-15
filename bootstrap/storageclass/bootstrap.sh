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

cloud_provider=$(yq r -e "${config_file}" 'global.cloudProvider')
if [ "${cloud_provider}" == "exoscale" ]
then
    NFS_SC_SERVER_IP=$(jq -r '.service_cluster.nfs_ip_addresses.nfs.private_ip' < "${config[infrastructure_file]}")
    export NFS_SC_SERVER_IP
    NFS_WC_SERVER_IP=$(jq -r '.workload_cluster.nfs_ip_addresses.nfs.private_ip' < "${config[infrastructure_file]}")
    export NFS_WC_SERVER_IP
fi

install_storage_class_provider "${storageClass}" "${environment}"
if [ "${environment}" == service_cluster ]; then
    install_storage_class_provider "${elasticStorageClass}" service_cluster
fi
