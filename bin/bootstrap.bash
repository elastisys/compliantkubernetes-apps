#!/bin/bash

# This script takes care of bootstrapping ck8s for service applications.
# It's not to be executed on its own but rather via `ck8s (bootstrap|apply)`.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

export bootstrap_path="${here}/../bootstrap"
export scripts_path

bootstrap_run_sc() {
    log_info "Bootstrapping service cluster"
    (
        with_kubeconfig "${secrets[kube_config_sc]}" \
            "${bootstrap_path}/bootstrap.sh" service_cluster
    )
}

bootstrap_run_wc() {
    log_info "Bootstrapping workload cluster"
    (
        with_kubeconfig "${secrets[kube_config_wc]}" \
            "${bootstrap_path}/bootstrap.sh" workload_cluster
    )
}

bootstrap_sc() {
    bootstrap_run_sc
}

bootstrap_wc() {
    bootstrap_run_wc
}

#
# ENTRYPOINT
#

if [[ $1 == "wc" ]]; then
    config_load "$1"
    bootstrap_wc
elif [[ $1 == "sc" ]]; then
    config_load "$1"
    bootstrap_sc
else
    echo "ERROR:  [$1] is an invalid argument:"
    echo "usage:   ck8s bootstrap <wc|sc>. "
    exit 1
fi
