#!/bin/bash
# (return 0 2>/dev/null) && sourced=1 || sourced=0

INNER_SCRIPTS_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=bin/common.bash
source "${INNER_SCRIPTS_PATH}/../funcs.sh"

function wc_ingress_check_help() {
    printf "%s\n" "[Usage]: test wc ingress [ARGUMENT]"
    printf "\t%-25s %s\n" "--health" "Check Ingress Health"
    printf "%s\n" "[NOTE] If no argument is specified, it will go over all of them."

    exit 0
}

function wc_ingress_checks() {
    if [[ ${#} == 0 ]]; then
        echo "Running all checks ..."
        check_wc_ingress_health
        return
    fi
    while [[ ${#} -gt 0 ]]; do
        case ${1} in
        --health)
            check_wc_ingress_health
            ;;
        --help)
            wc_ingress_check_help
            ;;
        esac
        shift
    done
}

function check_wc_ingress_health() {
    echo -ne "Checking Ingress Nginx health ... "
    no_error=true
    debug_msg=""

    desired_replicas=$(kubectl get daemonset -n ingress-nginx ingress-nginx-controller -ojson | jq ".status.desiredNumberScheduled | tonumber")
    ready_replicas=$(kubectl get daemonset -n ingress-nginx ingress-nginx-controller -ojson | jq ".status.numberReady | tonumber")
    has_proxy_protocol=$(kubectl get configmap -n ingress-nginx ingress-nginx-controller -oyaml | yq4 '.data.use-proxy-protocol')

    diff=$((desired_replicas - ready_replicas))
    if [[ $desired_replicas -eq $ready_replicas ]]; then
        read -r -a pods <<<"$(kubectl get pods -n ingress-nginx -ojson | jq -r '.items[].metadata.name' | tr '\n' ' ')"
        for pod in "${pods[@]}"; do
            if [[ "$pod" =~ ingress-nginx-controller* ]]; then
                extra_flags=""
                if "${has_proxy_protocol}"; then
                  extra_flags="--haproxy-protocol"
                fi
                # shellcheck disable=SC2086
                res=$(kubectl -n ingress-nginx exec -it "$pod" -- curl --retry 3 ${extra_flags} -w "%{http_code}" -o /dev/null -sk https://localhost/healthz)
                if [[ "$res" != "200" ]]; then
                    no_error=false
                    debug_msg+="[ERROR] The following nginx pod $pod is not healthy\n"
                fi
            fi
        done
    else
        no_error=false
        debug_msg+="[ERROR] $diff out of $desired_replicas of ingress-nginx-controller pods are not ready\n"
    fi

    if $no_error; then
        echo "success ✔"
        echo -e "[DEBUG] All nginx ingress pods are ready & healthy."
    else
        echo "failure ❌"
        echo -e "$debug_msg"
    fi
}
