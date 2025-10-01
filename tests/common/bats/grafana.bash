#!/usr/bin/env bash

# Helpers for interacting with Grafana:
# - _grafana.curl [method] [resource/path] [json data] <args...>  - curl helper function (not intended to be used outside of this file)
# - grafana.load_env [slug]                                       - setup endpoint and auth info; slug is one of ['ops_admin', 'user_admin', 'ops_static', 'user_static']
# - grafana.get_dashboards                                        - get all defined dashboards
# - grafana.load_actual_user                                      - load currently logged in user info into the environment
# - grafana.change_role [role]                                    - change user role with assertion
# - grafana.check_role [role]                                     - check user role

_grafana.curl() {
  local method="${1}"
  local path="${2}"
  local data="${3}"
  shift 3

  local url="https://${grafana_endpoint}/${path}"
  local curl_args=(-s -X "${method}" "${url}" -H "accept: application/json")

  if [[ -n "${grafana_basic_auth}" ]]; then
    curl_args+=(-u "${grafana_basic_auth}")
  elif [[ -n "${grafana_token}" ]]; then
    curl_args+=(-H "X-JWT-Assertion: ${grafana_token}")
  fi

  if [[ "${method}" == "POST" || "${method}" == "PUT" || "${method}" == "PATCH" ]]; then
    curl_args+=(-H "content-type: application/json" -d "${data}")
  fi

  curl "${curl_args[@]}" "$@"
}

grafana.load_env() {
  if ! [[ "${1:-}" =~ ^(ops_admin|user_admin|ops_static|user_static)$ ]]; then
    fail "invalid or missing slug argument"
  fi

  unset grafana_endpoint
  unset grafana_username
  unset grafana_password
  unset grafana_token

  case "${1}" in
  ops_admin | ops_static)
    grafana_endpoint="$(yq.get sc '.grafana.ops.subdomain + "." + .global.opsDomain')"
    ;;
  user_admin | user_static)
    grafana_endpoint="$(yq.get sc '.grafana.user.subdomain + "." + .global.baseDomain')"
    ;;
  *) return ;;
  esac
  export grafana_endpoint

  case "${1}" in
  ops_admin)
    grafana_basic_auth="admin:$(yq.secret ".grafana.password")"
    export grafana_basic_auth
    ;;
  user_admin)
    grafana_basic_auth="admin:$(yq.secret ".user.grafanaPassword")"
    export grafana_basic_auth
    ;;
  ops_static)
    local -r dex_url="$(yq.get sc '"https://dex." + .global.baseDomain + "/token"')"
    grafana_token="$(curl -s "$dex_url" --user "grafana-ops:$(yq.secret ".grafana.opsClientSecret")" \
      --data-urlencode grant_type=password \
      --data-urlencode username=admin@example.com \
      --data-urlencode password="$(yq.secret ".dex.staticPasswordNotHashed")" \
      --data-urlencode scope="openid email profile" | jq -r '.id_token')"
    export grafana_token
    ;;
  user_static)
    local -r dex_url="$(yq.get sc '"https://dex." + .global.baseDomain + "/token"')"
    grafana_token="$(curl -s "$dex_url" --user "grafana:$(yq.secret ".grafana.clientSecret")" \
      --data-urlencode grant_type=password \
      --data-urlencode username=dev@example.com \
      --data-urlencode password=password \
      --data-urlencode scope="openid email profile" | jq -r '.id_token')"
    export grafana_token
    ;;
  *) return ;;
  esac
}

grafana.get_dashboards() {
  _grafana.curl GET "apis/dashboard.grafana.app/v1beta1/namespaces/default/dashboards?limit=200" ""
}

grafana.load_actual_user() {
  local -r actual_user="$(_grafana.curl GET "api/user" "")"
  grafana_org_id="$(echo "$actual_user" | jq -r '.orgId')"
  grafana_user_id="$(echo "$actual_user" | jq -r '.id')"
}

grafana.change_role() {
  role="${1:-}"
  run _grafana.curl PATCH "api/orgs/${grafana_org_id}/users/${grafana_user_id}" "{\"role\":\"${role}\"}"
  assert_output --partial "Organization user updated"
}

grafana.check_role() {
  role="${1:-}"
  run bats_pipe _grafana.curl GET "api/users/${grafana_user_id}/orgs" "" \| jq -r '.[0].role'
  assert_line "${role}"
}
