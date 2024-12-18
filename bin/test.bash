#!/usr/bin/env bash

# This script tests the applications deployed via `ck8s apply`
# It's not to be executed on its own but rather via `ck8s test`.

set -eu -o pipefail

here="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${here}/common.bash"
# shellcheck source=pipeline/test/services/service-cluster/testOpensearch.sh
source "${pipeline_path}/test/services/service-cluster/testOpensearch.sh"
# shellcheck source=pipeline/test/services/service-cluster/testCertManager.sh
source "${pipeline_path}/test/services/service-cluster/testCertManager.sh"
# shellcheck source=pipeline/test/services/workload-cluster/testCertManager.sh
source "${pipeline_path}/test/services/workload-cluster/testCertManager.sh"
# shellcheck source=pipeline/test/services/service-cluster/testIngress.sh
source "${pipeline_path}/test/services/service-cluster/testIngress.sh"
# shellcheck source=pipeline/test/services/workload-cluster/testIngress.sh
source "${pipeline_path}/test/services/workload-cluster/testIngress.sh"
# shellcheck source=pipeline/test/services/workload-cluster/testHNC.sh
source "${pipeline_path}/test/services/workload-cluster/testHNC.sh"

test_apps_sc() {
  log_info "Testing service cluster"

  "${pipeline_path}/test/services/test-sc.sh" "${config[config_file_sc]}" "${@}"

}

test_apps_wc() {
  log_info "Testing workload cluster"

  "${pipeline_path}/test/services/test-wc.sh" "${config[config_file_wc]}" "${@}"

}

function sc_help() {
  printf "%s\n" "[Usage]: test sc [target] [ARGUMENTS]"
  printf "%s\n" "List of targets:"
  printf "\t%-23s %s\n" "apps" "Apps checks"
  printf "\t%-23s %s\n" "opensearch" "Open search checks"
  printf "\t%-23s %s\n" "cert-manager" "Cert Manager checks"
  printf "\t%-23s %s\n" "ingress" "Ingress checks"
  printf "%s\n" "[NOTE] If no target is specified, all of them will be executed."
  printf "%s\n" "[NOTE] Logging can be enabled for test sc and test sc apps by using the --logging-enabled flag."
}

function wc_help() {
  printf "%s\n" "[Usage]: test wc [target] [ARGUMENTS]"
  printf "%s\n" "List of targets:"
  printf "\t%-23s %s\n" "apps" "Apps checks"
  printf "\t%-23s %s\n" "cert-manager" "Cert Manager checks"
  printf "\t%-23s %s\n" "ingress" "Ingress checks"
  printf "\t%-23s %s\n" "hnc" "HNC checks"
  printf "%s\n" "[NOTE] If no target is specified, all of them will be executed."
  printf "%s\n" "[NOTE] Logging can be enabled for test wc and test wc apps by using the --logging-enabled flag."
}

function sc() {
  if [[ ${#} == 0 ]] || [[ ${#} == 1 && ${1} == "--logging-enabled" ]]; then
    set +e
    test_apps_sc "${@:1}"
    set -e
    log_info "Testing opensearch\n"
    sc_opensearch_checks
    echo
    log_info "Testing cert-manager\n"
    sc_cert_manager_checks
    echo
    log_info "Testing ingress\n"
    sc_ingress_checks
  else
    case ${1} in
    apps)
      test_apps_sc "${@:2}"
      ;;
    opensearch)
      sc_opensearch_checks "${@:2}"
      ;;
    cert-manager)
      sc_cert_manager_checks "${@:2}"
      ;;
    ingress)
      sc_ingress_checks "${@:2}"
      ;;
    --help | -h)
      sc_help
      ;;
    *)
      echo "unknown command: $1"
      sc_help 1
      exit 1
      ;;
    esac
  fi
  exit 0
}

function wc() {
  if [[ ${#} == 0 ]] || [[ ${#} == 1 && ${1} == "--logging-enabled" ]]; then
    set +e
    test_apps_wc "${@:1}"
    set -e
    log_info "Testing cert-manager\n"
    wc_cert_manager_checks
    echo
    log_info "Testing ingress\n"
    wc_ingress_checks
    echo
    log_info "Testing hnc\n"
    wc_hnc_checks

  else
    case ${1} in
    apps)
      test_apps_wc "${@:2}"
      ;;
    cert-manager)
      wc_cert_manager_checks "${@:2}"
      ;;
    ingress)
      wc_ingress_checks "${@:2}"
      ;;
    hnc)
      wc_hnc_checks "${@:2}"
      ;;
    --help | -h)
      wc_help
      ;;
    *)
      echo "unknown command: $1"
      wc_help 1
      exit 1
      ;;
    esac
  fi
  exit 0
}

function main_help() {
  echo list of commands:
  printf "%-23s %s\n" "help" "show help menu and commands"
  printf "%-23s %s\n" "sc" "Run sc checks"
  printf "%-23s %s\n" "wc" "Run wc checks"

  exit "${1:-0}"
}

function main() {
  if [[ ${#} == 0 ]]; then
    main_help 0
  fi

  case ${1} in
  sc)
    config_load "$1"
    "$1" "${@:2}"
    ;;
  wc)
    config_load "$1"
    "$1" "${@:2}"
    ;;
  esac
}

main "$@"
