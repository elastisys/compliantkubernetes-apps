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
      else
        log_info "Grafana releases are up to date, skipping"
      fi
      helmfile_apply sc app=grafana
      kubectl_do sc wait pod -n monitoring --for=condition=ready -l app.kubernetes.io/instance=user-grafana --timeout=120s

      if [[ $(yq4 '.global.clustersMonitoring | length' "${CK8S_CONFIG_PATH}/sc-config.yaml") -gt 1 ]]; then
        clusters_monitoring=$(yq4 '[.global.clustersMonitoring[] | {"name": .}]' "${CK8S_CONFIG_PATH}/sc-config.yaml" -ojson)
        export clusters_monitoring

        user_grafana_cm=$(kubectl_do sc get cm user-grafana -n monitoring -o=jsonpath='{.data.datasources\.yaml}' |
          yq4 '.deleteDatasources = env(clusters_monitoring)' -o json)

        PATCH="[
          {
            'op': 'replace',
            'path': '/data/datasources.yaml',
            'value': '${user_grafana_cm}'
          }
        ]"
        kubectl_do sc patch cm user-grafana -n monitoring --type json --patch "${PATCH}"
        kubectl_do sc rollout restart deployment user-grafana -n monitoring
        kubectl_do sc rollout status deployment user-grafana -n monitoring

        kubectl_do sc delete configmap user-grafana -n monitoring
        helmfile_do sc -l name=user-grafana sync

        kubectl_do sc rollout restart deployment user-grafana -n monitoring
        kubectl_do sc rollout status deployment user-grafana -n monitoring
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
