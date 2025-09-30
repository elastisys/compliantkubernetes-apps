#!/usr/bin/env bats

setup() {
  load "../../bats.lib.bash"
  load_common "grafana.bash"
  load_common "yq.bash"
  load_assert
}

grafana_load_actual_user() {
  local -r actual_user="$(grafana.get_actual_user)"
  grafana_org_id="$(echo "$actual_user" | jq -r '.orgId')"
  grafana_user_id="$(echo "$actual_user" | jq -r '.id')"
}

grafana_change_role() {
  role="${1:-}"
  run _grafana.curl PATCH "api/orgs/${grafana_org_id}/users/${grafana_user_id}" "{\"role\":\"${role}\"}"
  assert_output --partial "Organization user updated"
}

grafana_check_role() {
  role="${1:-}"
  run bats_pipe _grafana.curl GET "api/users/${grafana_user_id}/orgs" "" \| jq -r '.[0].role'
  assert_line "${role}"
}

# TODO - grafana config assertions

@test "ops grafana admin can promote static 'admin@example.com' user" {
  grafana.load_env "ops_static"
  grafana_load_actual_user

  grafana.load_env "ops_admin"
  grafana_change_role "Editor"
  grafana_check_role "Editor"

  grafana_change_role "Admin"
  grafana_check_role "Admin"
}

@test "user grafana admin can promote static 'dev@example.com' user" {
  grafana.load_env "user_static"
  grafana_load_actual_user

  grafana.load_env "user_admin"
  grafana_change_role "Editor"
  grafana_check_role "Editor"

  grafana_change_role "Admin"
  grafana_check_role "Admin"
}
