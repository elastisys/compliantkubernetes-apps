#!/bin/bash

if [[ "$#" -lt 1 ]]
then
  >&2 echo "Usage: source post-infra-common.sh path-to-infra-file "
  return 1
fi

infra="$1"
config="${CK8S_CONFIG_PATH}/sc-config.yaml"

# Common environment variables needed for deploy-*.sh
cloud_provider=$(yq r -e "$config" 'global.cloudProvider')
if [ "$cloud_provider" == "exoscale" ]
then
    NFS_SC_SERVER_IP=$(jq -r '.service_cluster.nfs_ip_addresses.nfs.private_ip' < "$infra")
    export NFS_SC_SERVER_IP
    NFS_WC_SERVER_IP=$(jq -r '.workload_cluster.nfs_ip_addresses.nfs.private_ip' < "$infra")
    export NFS_WC_SERVER_IP
fi
