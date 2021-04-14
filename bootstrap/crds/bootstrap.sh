#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "$0")")"
cd "$here"


environment=$1
declare -a kubectl_crd_args

parse_crd_list_file() {
    while IFS= read -r crd_file; do
        kubectl_crd_args+=("-f" "$crd_file")
    done < "$1"
}

case $environment in
    service_cluster)  parse_crd_list_file crds-sc.txt ;;
    workload_cluster) exit 0 ;;
    *) echo "Invalid environment: ${environment}"; exit 1 ;;
esac

kubectl apply "${kubectl_crd_args[@]}"
