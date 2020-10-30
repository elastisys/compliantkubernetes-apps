#!/bin/bash

# This script takes care of deploying the ck8s service applications.
# It's not to be executed on its own but rather via `ck8s (apps|apply)`.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck disable=SC1090
source "${here}/common.bash"

apps_init() {
    log_info "Initializing applications"

    # Get helm major version
    helm_version=$(KUBECONFIG="" helm version -c --short | tr -d 'Client: v' | head -c 1)
    if [ "${helm_version}" != "3" ]; then
        log_error "Only helm 3 is supported"
        exit 1
    fi

    # TODO: We should try to get rid of the post-infra-common script.

    log_info "Running post infra script"
    : "${scripts_path:?Missing scripts path}"
    : "${config[infrastructure_file]:?Missing infrastructure file}"
    # shellcheck disable=SC1090
    source "${scripts_path}/post-infra-common.sh" \
        "${config[infrastructure_file]}"
}

apps_run_sc() {
    log_info "Applying applications in service cluster"

    (
        : "${scripts_path:?Missing scripts path}"
        : "${secrets[kube_config_sc]:?Missing service cluster kubeconfig}"
        with_kubeconfig "${secrets[kube_config_sc]}" \
            CONFIG_PATH="${CK8S_CONFIG_PATH}" "${scripts_path}/deploy-sc.sh"
    )
}

apps_run_wc() {
    log_info "Applying applications in workload cluster"

    (
        : "${scripts_path:?Missing scripts path}"
        : "${secrets[kube_config_wc]:?Missing workload cluster kubeconfig}"
        with_kubeconfig "${secrets[kube_config_wc]}" \
            CONFIG_PATH="${CK8S_CONFIG_PATH}" "${scripts_path}/deploy-wc.sh"
    )
}

apps_sc() {
    apps_init
    apps_run_sc

    log_info "Applications applied successfully!"
}

apps_wc() {
    apps_init
    apps_run_wc

    log_info "Applications applied successfully!"
}

#
# ENTRYPOINT
#


if [[ $1 == "wc" ]]; then
    config_load "$1"
    apps_wc
elif [[ $1 == "sc" ]]; then
    config_load "$1"
    apps_sc
else
    echo "ERROR:  [$1] is an invalid argument:"
    echo "usage:   ck8s apps <wc|sc>. "
    exit 1
fi
