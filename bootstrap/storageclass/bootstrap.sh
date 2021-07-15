#!/usr/bin/env bash

#
# Todo: chartify all storageclasses and this "complicated" bootstrap logic
#       of storageclasses can be reduced to a single "helmfile apply".
#

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"

# TODO: required by install-storage-class-provider, probably better to rewrite
# it to not require this variable.
export storageclass_path="${here}"

# shellcheck source=bootstrap/storageclass/scripts/install-storage-class-provider.sh
source "${here}/scripts/install-storage-class-provider.sh"
# shellcheck source=bin/common.bash
source "${here}/../../bin/common.bash"

environment="${1}"

case ${environment} in
    service_cluster)
        config_load sc --skip-validation
        config_file="${config["config_file_sc"]}"
        ;;
    workload_cluster)
        config_load wc --skip-validation
        config_file="${config["config_file_wc"]}"
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
