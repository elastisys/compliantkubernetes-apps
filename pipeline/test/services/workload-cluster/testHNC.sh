#!/bin/bash
# (return 0 2>/dev/null) && sourced=1 || sourced=0

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=bin/common.bash
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

function wc_hnc_check_help() {
    printf "%s\n" "[Usage]: test wc hnc [ARGUMENT]"
    printf "\t%-25s %s\n" "--subns-anchors" "Check that users can create sub namespace anchors and remove them"
    printf "\t%-25s %s\n" "--system-namespaces" "Check that no system namespace is labelled by HNC"
    printf "%s\n" "[NOTE] If no argument is specified, it will go over all of them."

    exit 0
}

function wc_hnc_checks() {
    if [[ ${#} == 0 ]]; then
        echo "Running all checks ..."
        check_wc_hnc_creation_removal
        check_wc_hnc_system_namespaces
        exit 0
    fi
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
        --subns-anchors)
            check_wc_hnc_creation_removal
            ;;
        --system-namespaces)
            check_wc_hnc_system_namespaces
            ;;
        --help)
            wc_hnc_check_help
            ;;
        esac
        shift
    done
}

function check_wc_hnc_creation_removal() {
    echo -ne "Checking that users can create/delete sub namespaces ... "
    no_error=true
    debug_msg=""

    user_namespaces=$(yq4 -e '.user.namespaces[]' "${config['config_file_wc']}")
    user_admin_users=$(yq4 -e '.user.adminUsers[]' "${config['config_file_wc']}")

    VERBS=(
        create
        delete
        patch
        update
    )

    CK8S_NAMESPACES=(
        cert-manager
        default
        falco
        fluentd
        kube-system
        monitoring
        ingress-nginx
        velero
    )

    for user in ${user_admin_users}; do
        for namespace in ${user_namespaces}; do
            for verb in "${VERBS[@]}"; do
                if ! kubectl auth can-i "$verb" "subns" -n "$namespace" --as "$user" >/dev/null 2>&1; then
                    no_error=false
                    debug_msg+="[ERROR] $user cannot $verb sub namespace under $namespace namespace\n"
                fi
            done
        done
    done

    for user in ${user_admin_users}; do
        for namespace in "${CK8S_NAMESPACES[@]}"; do
            for verb in "${VERBS[@]}"; do
                if kubectl auth can-i "$verb" "subns" -n "$namespace" --as "$user" >/dev/null 2>&1; then
                    no_error=false
                    debug_msg+="[ERROR] $user can $verb subnamespace anchors under $namespace namespace\n"
                fi
            done
        done
    done

    if $no_error; then
        echo "success ✔"
        echo -e "[DEBUG] Users are able to create/delete subnamespaces anchors"
    else
        echo "failure ❌"
        echo -e "$debug_msg"
    fi
}

function check_wc_hnc_system_namespaces() {
    echo -ne "Checking that system namespaces are not labelled by HNC ... "
    no_error=true
    debug_msg=""

    CK8S_NAMESPACES=(
        cert-manager
        falco
        fluentd
        kube-system
        monitoring
        ingress-nginx
        velero
    )

    for namespace in "${CK8S_NAMESPACES[@]}"; do
        hnc_label_exists=$(kubectl get ns "$namespace" -ojson | jq -r '.metadata.labels | .["hnc.x-k8s.io/included-namespace"]')
        if [[ "$hnc_label_exists" == "true" ]]; then
            no_error=false
            debug_msg+="[ERROR] The $namespace namespace is labelled by HNC\n"
        fi
    done

    if $no_error; then
        echo "success ✔"
        echo -e "[DEBUG] No system namespace is labelled by HNC"
    else
        echo "failure ❌"
        echo -e "$debug_msg"
    fi
}
