#!/bin/bash

# This script tests the applications deployed via `ck8s apply`
# It's not to be executed on its own but rather via `ck8s test`.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1090
source "${here}/common.bash"

test_apps_sc() {
    log_info "Testing service cluster"

    : "${secrets[kube_config_sc]:?Missing service cluster kubeconfig}"
    : "${config[config_file_sc]:?Missing service cluster config}"
    : "${pipeline_path:?Missing pipeline path}"
    with_kubeconfig "${secrets[kube_config_sc]}" \
        "${pipeline_path}/test/services/test-sc.sh" "${config[config_file_sc]}"
}

test_apps_wc() {
    log_info "Testing workload cluster"

    : "${secrets[kube_config_wc]:?Missing workload cluster kubeconfig}"
    : "${config[config_file_wc]:?Missing workload cluster config}"
    : "${pipeline_path:?Missing pipeline path}"
    with_kubeconfig "${secrets[kube_config_wc]}" \
        "${pipeline_path}/test/services/test-wc.sh" "${config[config_file_wc]}"
}

#
# ENTRYPOINT
#

config_load "$1"
if [[ $1 == "wc" ]]; then
    test_apps_wc
elif [[ $1 == "sc" ]]; then
    test_apps_sc
else
    echo "ERROR:  [$1] is an invalid argument:"
    echo "usage:   ck8s test <wc|sc>. "
    exit 1
fi
