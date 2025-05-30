#!/usr/bin/env bats

# bats file_tags=static,general,bin:version

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"
  load_mock

  gpg.setup
  env.setup
  env.init baremetal kubespray prod
  yq -i '.global.ck8sVersion = "v0.42"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"

  mock_kubectl="$(mock_create)"
  export mock_kubectl
  kubectl() {
    # shellcheck disable=SC2317
    "${mock_kubectl}" "${@}"
  }
  export -f kubectl
  mock_set_output "${mock_kubectl}" "v0.42"
}

teardown_file() {
  env.teardown
  gpg.teardown
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

@test "negative test should show usage" {
  run ck8s version
  assert_failure
  assert_output --partial "version <all|both|config|sc|wc>"
}

@test "ck8s version all" {
  run ck8s version all
  assert_success
  assert_output --partial "config version: v0.42"
  assert_output --partial "sc version: v0.42"
  assert_output --partial "wc version: v0.42"
}

@test "ck8s version both" {
  run ck8s version both
  assert_success
  assert_output --partial "sc version: v0.42"
  assert_output --partial "wc version: v0.42"
}

@test "ck8s version config" {
  run ck8s version config
  assert_success
  assert_output --partial "config version: v0.42"
}

@test "ck8s version sc" {
  run ck8s version sc
  assert_success
  assert_output --partial "sc version: v0.42"
}

@test "ck8s version wc" {
  run ck8s version wc
  assert_success
  assert_output --partial "wc version: v0.42"
}
