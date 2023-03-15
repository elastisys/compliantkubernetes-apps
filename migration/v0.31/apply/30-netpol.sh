#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    log_info "upgrading sc networkpolicies"
    helmfile_upgrade sc netpol=common netpol=service
    helmfile_upgrade sc 'app=netpol,netpol!=common,netpol!=service'

    log_info "upgrading wc networkpolicies"
    helmfile_upgrade wc netpol=common netpol=workload
    helmfile_upgrade wc 'app=netpol,netpol!=common,netpol!=workload'
    ;;

  rollback)
    log_warn "rolling back sc networkpolicies"
    helmfile_destroy sc 'app=netpol,netpol!=common,netpol!=service'
    if [[ "$(helm_chart_version sc kube-system common-np)" == "0.2.0" ]]; then
      helm_rollback sc kube-system common-np
    fi
    if [[ "$(helm_chart_version sc kube-system service-cluster-np)" == "0.2.0" ]]; then
      helm_rollback sc kube-system service-cluster-np
    fi

    log_warn "rolling back wc networkpolicies"
    helmfile_destroy wc 'app=netpol,netpol!=common,netpol!=workload'
    if [[ "$(helm_chart_version wc kube-system common-np)" == "0.2.0" ]]; then
      helm_rollback wc kube-system common-np
    fi
    if [[ "$(helm_chart_version wc kube-system workload-cluster-np)" == "0.2.0" ]]; then
      helm_rollback wc kube-system workload-cluster-np
    fi
    ;;

  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
