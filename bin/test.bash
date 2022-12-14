#!/bin/bash

# This script tests the applications deployed via `ck8s apply`
# It's not to be executed on its own but rather via `ck8s test`.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"
# shellcheck source=pipeline/test/services/service-cluster/testOpensearch.sh
source "${pipeline_path}/test/services/service-cluster/testOpensearch.sh"

test_apps_sc() {
    log_info "Testing service cluster"

    with_kubeconfig "${config[kube_config_sc]}" \
        "${pipeline_path}/test/services/test-sc.sh" "${config[config_file_sc]}"
}

test_apps_wc() {
    log_info "Testing workload cluster"

    with_kubeconfig "${config[kube_config_wc]}" \
        "${pipeline_path}/test/services/test-wc.sh" "${config[config_file_wc]}"
}

function sc_help(){
    printf "%s\n" "[Usage]: test sc [target] [ARGUMENTS]";
    printf "%s\n" "List of targets:";
    printf "\t%-23s %s\n" "opensearch" "Open search checks";
    printf "\t%-23s %s\n" "fluentd" "Fluentd checks";
    printf "\t%-23s %s\n" "opensearch-dashboards" "Opensearch dashboards checks";
    printf "%s\n" "[NOTE] If no target is specified, the tests will go through all of them.";
    exit 0;
}

function sc() {
    if [[ ${#} == 0 ]]; then
        test_apps_sc
    else
        case ${1} in
            opensearch )
                sc_opensearch_checks "${@:2}";
            ;;
            --help )
              sc_help
            ;;
            * )
                echo "unknown command: $1";
                sc_help 1;
                exit 1;
            ;;
        esac
    fi
    exit 0;
}

function main_help(){
    echo list of commands:
    printf "%-23s %s\n" "help" "show help menu and commands";
    printf "%-23s %s\n" "sc" "Run sc checks";
    printf "%-23s %s\n" "wc" "Run wc checks";

    exit "${1:-0}";
}

function main(){
    if [[ ${#} == 0 ]]; then
        main_help 0;
    fi

    case ${1} in
        sc )
            config_load "$1";
            with_kubeconfig "${config[kube_config_sc]}" \
              "$1" "${@:2}";
        ;;
        wc )
            config_load "$1";
            with_kubeconfig "${config[kube_config_wc]}" \
              "$1" "${@:2}";
        ;;
    esac
}

main "$@";
