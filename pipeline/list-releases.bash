#!/bin/bash

# This script:
## Lists helm releases
## Gets failed helm releases
## Print k8s objects in namespaces with a failed release

set -eu -o pipefail

here="$(dirname "$(readlink -f "${0}")")"
bin_path="${here}/../bin"

# shellcheck source=pipeline/common.bash
source "${here}/common.bash"
# shellcheck source=bin/common.bash
source "${bin_path}/common.bash"

if [ "${#}" -ne 1 ]; then
    echo "Missing cluster paramter"
    exit 1
fi

cluster="${1}"
cluster_abbr=""

if [ "${cluster}" = "service_cluster" ]; then
    config_load sc
    kubeconfig="${secrets[kube_config_sc]}"
    cluster_abbr="sc"
elif [ "${cluster}" = "workload_cluster" ]; then
    config_load wc
    kubeconfig="${secrets[kube_config_wc]}"
    cluster_abbr="wc"
fi


echo "###############################"
echo -e "Listing helm releases\n"

"${bin_path}"/ck8s ops helmfile "${cluster_abbr}" status

failed_releases=$("${bin_path}"/ck8s ops helmfile "${cluster_abbr}" status --args="--output=json" \
    | jq 'select(.info.status=="failed")')

echo -e "###############################\n"

namespaces=$(echo "${failed_releases}" | jq '.namespace ' | jq -rs 'unique | .[]')

ck8s_kubectl () {
    # shellcheck disable=SC2068
    with_kubeconfig "${kubeconfig}" kubectl ${@}
}

# Maybe we should set this through pipeline a variable?
get_resource_list="all pvc secrets certificates ingresses"

# shellcheck disable=SC2068
for namespace in ${namespaces}; do
    for resource in ${get_resource_list}; do
        echo -e "Listing '${resource}' in namespace '${namespace}'\n"
        ck8s_kubectl -n "${namespace}" get "${resource}"
        echo
    done
done
