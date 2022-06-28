#!/bin/bash

# This script takes care of deploying the ck8s service applications.
# It's not to be executed on its own but rather via `ck8s (apps|apply)`.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"

apps_init() {
    log_info "Initializing applications"

    # Get helm major version
    helm_version=$(KUBECONFIG="" helm version -c --short | tr -d 'Client: v' | head -c 1)
    if [ "${helm_version}" != "3" ]; then
        log_error "Only helm 3 is supported"
        exit 1
    fi
}

apps_run_sc() {
    log_info "Applying applications in service cluster"
    (
        with_kubeconfig "${config[kube_config_sc]}" \
            "${scripts_path}/deploy-sc.sh" "${1:-""}"
    )
}

apps_run_wc() {
    log_info "Applying applications in workload cluster"
    (
        with_kubeconfig "${config[kube_config_wc]}" \
             "${scripts_path}/deploy-wc.sh" "${1:-""}"
    )
}

template_validate_sc() {
    log_info "Validating helm releases in service cluster"

    kubeconfig="${config[kube_config_sc]}"

    with_kubeconfig "${kubeconfig}" \
        helmfile -f "${here}/../helmfile/" -e service_cluster template --validate >/dev/null

    log_info "Validation of helm releases completed successfully"
}

template_validate_wc() {
    log_info "Validating helm releases in workload cluster"

    kubeconfig="${config[kube_config_wc]}"

    with_kubeconfig "${kubeconfig}" \
        helmfile -f "${here}/../helmfile/" -e workload_cluster template --validate >/dev/null

    log_info "Validation of helm releases completed successfully"
}

apps_sc() {
    apps_init
    #
    # The first few Charts install CRDs, which will make template validation
    # fail. CRDs are "changes" to the Kubernetes API, hence validation against
    # the Kubernetes API cannot be done. OTOH, manually adding the CRDs during
    # bootstrap is error-prone and adds maintenance burden.
    #
    # While it would be nice to have some template validation before `helmfile apply`,
    # at least Helmfile does "just in time" template validation. Not as nice,
    # but feels good enough until we figure out something smarter.
    #
    #[ "$1" != "--skip-template-validate" ] && template_validate_sc

    apps_run_sc "${2:-""}"

    log_info "Applications applied successfully!"
}

apps_wc() {
    apps_init
    # See rationale above
    #[ "$1" != "--skip-template-validate" ] && template_validate_wc

    apps_run_wc "${2:-""}"

    log_info "Applications applied successfully!"
}

#
# ENTRYPOINT
#
if [[ $1 == "wc" ]]; then
    config_load "$1"
    apps_wc "$2" "$3"
elif [[ $1 == "sc" ]]; then
    config_load "$1"
    apps_sc "$2" "$3"
else
    echo "ERROR:  [$1] is an invalid argument:"
    echo "usage:   ck8s apps <wc|sc>. "
    exit 1
fi
