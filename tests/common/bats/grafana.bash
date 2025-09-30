#!/usr/bin/env bash

# Helpers for interacting with Grafana:
# - _grafana.curl [method] [resource/path] [json data] <args...>                 - curl helper function (not intended to be used outside of this file)
# - grafana.load_env [slug]                                                      - setup endpoint and auth info; slug is one of ['ops', 'user']

_grafana.curl() {
  local method="${1}"
  local path="${2}"
  local data="${3}"
  shift 3

  local url="https://${grafana_endpoint}/${path}"
  local curl_args=(-s -u "${grafana_username}:${grafana_password}" -X "${method}" "${url}" -H "accept: application/json")

  if [[ "${method}" == "POST" || "${method}" == "PUT" || "${method}" == "PATCH" ]]; then
    curl_args+=(-H "content-type: application/json" -d "${data}")
  fi

  curl "${curl_args[@]}" "$@"
}

grafana.load_env() {
  if ! [[ "${1:-}" =~ ^(ops|user)$ ]]; then
    fail "invalid or missing slug argument"
  fi

  grafana_username="admin"

  case "${1}" in
  ops)
    grafana_endpoint="$(yq.get sc '.grafana.ops.subdomain + "." + .global.opsDomain')"
    grafana_password="$(yq.secret ".grafana.password")"
  ;;
  user)
    grafana_endpoint="$(yq.get sc '.grafana.user.subdomain + "." + .global.baseDomain')"
    grafana_password="$(yq.secret ".user.grafanaPassword")"
  ;;
  *) return ;;
  esac

  export grafana_username
  export grafana_endpoint
  export grafana_password
}

grafana.get_dashboards() {
  _grafana.curl GET "apis/dashboard.grafana.app/v1beta1/namespaces/default/dashboards?limit=200" ""
}
