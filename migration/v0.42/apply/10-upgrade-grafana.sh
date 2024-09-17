#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "Checking current Grafana release versions"

      ops_version=$(helm_do sc get metadata -n monitoring ops-grafana -ojson | jq '.version' | tr -d '"')
      user_version=$(helm_do sc get metadata -n monitoring user-grafana -ojson | jq '.version' | tr -d '"')

      if [[ "${ops_version}" < "8.4.7" || "${user_version}" < "8.4.7" ]]; then
        log_info "Deleting Grafana release secrets."
        kubectl_do sc delete secrets -n monitoring -l name=ops-grafana,owner=helm
        kubectl_do sc delete secrets -n monitoring -l name=user-grafana,owner=helm

        helmfile_apply sc app=grafana
      else
        log_info "Grafana releases are up to date, skipping"
      fi

    fi
    ;;
  rollback)
    log_warn "rollback not implemented"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
