#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  mark.setup
  mark.punch
}

setup() {
  load "../../bats.lib.bash"
  load_common "grafana.bash"
  load_common "yq.bash"
  load_assert

  mark.check
}

teardown() {
  if [[ "${BATS_TEST_COMPLETED:-}" == 1 ]]; then
    mark.punch
  fi
}

teardown_file() {
  mark.teardown
}

@test "user grafana should be properly configured" {
  # cypress does not like trailing dots
  run yq.get sc '.grafana.user.trailingDots'
  refute_output "true"

  # skipRoleSync must be true
  run yq.get sc '.grafana.user.oidc.skipRoleSync'
  assert_output "true"

  # JWT auth must be enabled
  run yq.get sc '.grafana.user.oidc.jwtEnabled'
  assert_output "true"

  # dex.enableStaticLogin must be true
  run yq.get sc '.dex.enableStaticLogin'
  assert_output "true"

  # 'example.com' must be in grafana.ops.oidc.allowedDomains
  run yq.get sc '.grafana.user.oidc.allowedDomains'
  assert_output --regexp '- example.com$'
}

@test "user grafana admin can promote static 'dev@example.com' user" {
  grafana.load_env "user_static"
  grafana.load_actual_user

  grafana.load_env "user_admin"
  grafana.change_role "Editor"
  grafana.check_role "Editor"

  grafana.change_role "Admin"
  grafana.check_role "Admin"
}
