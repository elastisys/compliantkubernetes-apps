#!/usr/bin/env bash

#
# Todo: chartify all storageclasses and this "complicated" bootstrap logic
#       of storageclasses can be reduced to a single "helmfile apply".
#

set -euo pipefail

environment="${1}"
# shellcheck disable=SC1090
source "${common_path:?Missing common path}"
# shellcheck disable=SC1090
source "${storageclass_path:?Missing storageclass path}/scripts/install-storage-class-provider.sh"

case ${environment} in
    service_cluster)
        config_file="${config["config_file_sc"]:?Missing service cluster config}"
        ;;
    workload_cluster)
        config_file="${config["config_file_wc"]:?Missing workload cluster config}"
        ;;
esac

# Map of storageclasses to storageclassnames
declare -A storageClasses=(
    ["nfs"]="nfs-client"
    ["cinder"]="cinder-storage"
    ["local"]="local-storage"
    ["ebs"]="ebs-gp2"
)

# shellcheck disable=SC2068
for storageClass in ${!storageClasses[@]}; do
    if [ "$(yq r -e "${config_file}" 'storageClasses.'"${storageClass}"'.enabled')" = "true" ]; then
        install_storage_class_provider "${storageClasses[${storageClass}]}" "${environment}"
    fi
done
