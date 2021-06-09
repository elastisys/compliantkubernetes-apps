#!/bin/bash

# This script tests the applications deployed via `ck8s apply`
# It's not to be executed on its own but rather via `ck8s test`.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

test_apps_sc() {
    log_info "Testing service cluster"

    with_kubeconfig "${secrets[kube_config_sc]}" \
        "${pipeline_path}/test/services/test-sc.sh" "${config[config_file_sc]}"
}

test_apps_wc() {
    log_info "Testing workload cluster"

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
