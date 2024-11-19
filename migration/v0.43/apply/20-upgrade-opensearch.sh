#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

clone_opensearch_dashboard_index() {

  log_info "- Cloning index .opensearch_dashboards to .kibana"
  log_info "- Getting name of .opensearch_dashboards index"
  os_dashboards_index=$(curl -sS -kL -u "${user}:${password}" -X GET "${os_url}"/_alias/.opensearch_dashboards | jq -r 'to_entries | .[0].key')

  if [[ "${os_dashboards_index}" != .opensearch_dashboards* ]]; then
    log_fatal "Failed to get index name of the .opensearch_dashboards alias"
  fi

  log_info "- Marking index '${os_dashboards_index}' as read-only"
  resp=$(curl -sS -kL -u "${user}:${password}" -X PUT "${os_url}"/"${os_dashboards_index}"/_settings -H 'Content-Type: application/json' -d'
  {
    "settings": {
      "index.blocks.write": true
    }
  }
  ')

  acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
  if [ "${acknowledged}" = "true" ]; then
    log_info "- Marked '${os_dashboards_index}' as read-only"
  else
    log_fatal "Failed to mark index '${os_dashboards_index}' as read-only" "${resp}"
  fi

  log_info "- Cloning index '${os_dashboards_index}' to index .kibana_1"
  resp=$(curl -sS -kL -u "${user}:${password}" -X PUT "${os_url}"/"${os_dashboards_index}"/_clone/.kibana_1)
  acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
  if [ "${acknowledged}" = "true" ]; then
    log_info "- Successfully cloned '${os_dashboards_index}' to .kibana_1"
  else
    log_fatal "Failed to clone index '${os_dashboards_index}' to .kibana_1" "${resp}"
  fi

}

disable_read_only_kibana_index() {

  log_info "- Disabling read-only mode for .kibana_1"
  resp=$(curl -sS -kL -u "${user}:${password}" -X PUT "${os_url}"/.kibana_1/_settings -H 'Content-Type: application/json' -d'
  {
    "settings": {
      "index.blocks.write": false
    }
  }
  ')
  acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
  if [ "${acknowledged}" = "true" ]; then
    log_info "- Successfully disabled read-only mode for .kibana_1"
  else
    log_fatal "Failed to disable read-only mode for .kibana_1" "${resp}"
  fi

}

create_kibana_alias() {

  resp=$(curl -sS -kL -u "${user}:${password}" -X GET "${os_url}"/_alias/.kibana)
  if [[ $(echo "${resp}" | jq -r 'to_entries | .[0].key') == .kibana* ]]; then
    log_info "- Alias .kibana already exists, skipping"
  elif [[ $(echo "${resp}" | jq -r '.status') == "404" ]]; then
    log_info "- Creating alias .kibana"
    resp=$(curl -sS -kL -u "${user}:${password}" -X PUT "${os_url}"/.kibana_1/_aliases/.kibana)
    acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
    if [ "${acknowledged}" = "true" ]; then
      log_info "- Successfully created alias .kibana"
    else
      log_fatal "Failed to create alias .kibana" "${resp}"
    fi
  else
    log_fatal "Failed to check if alias .kibana exists" "${resp}"
  fi

}

delete_opensearch_dashboards_index() {

  os_dashboards_index=$(curl -sS -kL -u "${user}:${password}" -X GET "${os_url}"/_alias/.opensearch_dashboards | jq -r 'to_entries | .[0].key')
  if [[ "${os_dashboards_index}" != .opensearch_dashboards* ]]; then
    log_info "- Skipping: Alias .opensearch_dashboards doesn't exist"
  else
    log_info "- Deleting all .opensearch_dashboards* indices"
    resp=$(curl -sS -kL -u "${user}:${password}" -X DELETE "${os_url}"/".opensearch_dashboards*")
    acknowledged=$(echo "${resp}" | grep "^{" | jq -r '.acknowledged')
    if [ "${acknowledged}" = "true" ]; then
      log_info "- Successfully deleted all .opensearch_dashboards* indices"
    else
      log_fatal "Failed to delete all .opensearch_dashboards* indices" "${resp}"
    fi
  fi

}

run() {
  case "${1:-}" in
  execute)

    if [[ "${CK8S_CLUSTER}" =~ ^(sc|both)$ ]]; then
      log_info "operation on service cluster"

      if [[ ! "$(helm_chart_version "sc" opensearch-system opensearch-master)" = "2.26.1" ]]; then

        log_info "- Scaling down opensearch-dashboards to 0 replicas"
        kubectl_do sc -n opensearch-system scale deployment opensearch-dashboards --replicas=0

        user="admin"
        password=$(sops --config "${CK8S_CONFIG_PATH}/.sops.yaml" -d "${CK8S_CONFIG_PATH}"/secrets.yaml | yq4 '.opensearch.adminPassword')
        os_url=https://opensearch.$(yq4 '.global.opsDomain' "${CK8S_CONFIG_PATH}"/common-config.yaml)

        resp=$(curl -sS -kL -u "${user}:${password}" -X GET "${os_url}"/.kibana_1)
        if [[ $(echo "${resp}" | jq -r 'to_entries | .[0].key') == ".kibana_1" ]]; then

          log_info "- Index .kibana_1 already exists, skipping"

        elif [[ $(echo "${resp}" | jq -r '.error.type') == "index_not_found_exception" ]]; then

          clone_opensearch_dashboard_index

        else

          log_fatal "Failed to check if index .kibana_1 already exists" "${resp}"

        fi

        disable_read_only_kibana_index
        create_kibana_alias
        delete_opensearch_dashboards_index

        log_info "- Removing opensearch-configurer"
        helmfile_destroy sc name=opensearch-configurer
        log_info "- Upgrading Opensearch"
        helmfile_do sc -lapp=opensearch sync

      else

        log_info "- OpenSearch chart version already 2.26.1, executing generic apply"
        helmfile_upgrade sc app=opensearch

      fi
    fi
    ;;
  rollback)
    log_warn "rollback not applicable"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
