#!/usr/bin/env bats

# bats file_tags=static,general,bin:version

setup_file() {
  load "../../bats.lib.bash"
}

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_assert
  load_file

  CK8S_CONFIG_PATH="$(mktemp --directory)"
  export CK8S_CONFIG_PATH
  export CK8S_ENVIRONMENT_NAME="unit-test"
  export CK8S_CLOUD_PROVIDER="baremetal"
  export CK8S_K8S_INSTALLER="kubespray"
  export CK8S_FLAVOR="dev"
}

@test "negative test should show usage" {
  run ck8s version
  assert_failure
  assert_output --partial "version <all|both|config|sc|wc>"
}

@test "ck8s version all" {
  run ck8s version all
  assert_success
  assert_output --partial "config version: "
  assert_output --partial "sc version: "
  assert_output --partial "wc version: "
}

@test "ck8s version both" {
  run ck8s version both
  assert_success
  assert_output --partial "sc version: "
  assert_output --partial "wc version: "
}

@test "ck8s version config" {
  run ck8s version config
  assert_success
  assert_output --partial "config version: "
}

@test "ck8s version sc" {
  run ck8s version sc
  assert_success
  assert_output --partial "sc version: "
}

@test "ck8s version wc" {
  run ck8s version wc
  assert_success
  assert_output --partial "wc version: "
}
