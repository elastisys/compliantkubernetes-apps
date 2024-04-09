#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
  log_info "- check it Grafana groups are used"
  grafanaGroups=("grafanaAdmin" "grafanaEditor" "grafanaViewer")

  for group in "${grafanaGroups[@]}"; do
    if ! yq_null sc .grafana.user.oidc.userGroups."${group}"; then
      declare "${group}"="$(yq4 ".grafana.user.oidc.userGroups.${group} | select(. != \"*elastisys.com\")" "${CK8S_CONFIG_PATH}"/sc-config.yaml)"
    else
      declare "${group}"=""
    fi
  done
  if [ -n "${grafanaAdmin}" ] || [ -n "${grafanaEditor}" ] || [ -n "${grafanaViewer}" ]; then
    log_info "- applications developer groups are used, exit"
    exit 0
  else
    yq_add sc .grafana.user.oidc.skipRoleSync true
  fi
fi
