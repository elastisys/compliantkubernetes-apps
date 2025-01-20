#!/usr/bin/env bats

# bats file_tags=static,general,bin:init

setup_file() {
  load "../../bats.lib.bash"
  load_common "gpg.bash"

  gpg.setup
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

teardown() {
  env.teardown
}

teardown_file() {
  gpg.teardown
}

@test "ck8s init requires CK8S_CONFIG_PATH" {
  CK8S_CONFIG_PATH="" run ck8s init both

  assert_failure
  assert_output --partial "Missing CK8S_CONFIG_PATH"
}

@test "ck8s init requires CK8S_ENVIRONMENT_NAME" {
  CK8S_ENVIRONMENT_NAME="" run ck8s init both

  assert_failure
  assert_output --partial "Missing CK8S_ENVIRONMENT_NAME"
}

@test "ck8s init requires CK8S_CLOUD_PROVIDER" {
  CK8S_CLOUD_PROVIDER="" run ck8s init both

  assert_failure
  assert_output --partial "Missing CK8S_CLOUD_PROVIDER"
}

@test "ck8s init requires requires CK8S_K8S_INSTALLER" {
  CK8S_K8S_INSTALLER="" run ck8s init both

  assert_failure
  assert_output --partial "Missing CK8S_K8S_INSTALLER"
}

@test "ck8s init requires CK8S_FLAVOR" {
  CK8S_FLAVOR="" run ck8s init both

  assert_failure
  assert_output --partial "Missing CK8S_FLAVOR"
}

@test "ck8s init requires valid CK8S_PGP_FP or valid CK8S_PGP_UID" {
  unset CK8S_PGP_FP

  run ck8s init both
  assert_failure
  assert_output --partial "CK8S_PGP_FP and CK8S_PGP_UID can't both be unset"

  CK8S_PGP_FP="123" run ck8s init both
  assert_failure
  assert_output --partial "Fingerprint 123 does not exist in gpg keyring"

  CK8S_PGP_UID="asd" run ck8s init both
  assert_failure
  assert_output --partial "Unable to get fingerprint from gpg keyring using UID"
}

@test "ck8s init checks supported cloud providers" {
  CK8S_CLOUD_PROVIDER=foo run ck8s init both

  assert_failure
  assert_output --partial "Unsupported cloud provider: foo"
}

@test "ck8s init checks supported flavors" {
  CK8S_FLAVOR=foo run ck8s init both

  assert_failure
  assert_output --partial "Unsupported flavor: foo"
}

@test "ck8s init creates environment config" {
  run ck8s init both
  assert_success

  assert_file_exists "${CK8S_CONFIG_PATH}/common-config.yaml"
  assert_file_exists "${CK8S_CONFIG_PATH}/sc-config.yaml"
  assert_file_exists "${CK8S_CONFIG_PATH}/wc-config.yaml"

  assert_file_exists "${CK8S_CONFIG_PATH}/secrets.yaml"

  assert_file_contains "${CK8S_CONFIG_PATH}/secrets.yaml" "sops:"

  assert_file_exists "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  assert_file_exists "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"
  assert_file_exists "${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"

  assert_file_permission 444 "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  assert_file_permission 444 "${CK8S_CONFIG_PATH}/defaults/sc-config.yaml"
  assert_file_permission 444 "${CK8S_CONFIG_PATH}/defaults/wc-config.yaml"
}

@test "ck8s init backups environment config" {
  run ck8s init both

  assert_success

  run ck8s init both

  assert_success

  assert_file_exists "${CK8S_CONFIG_PATH}"/backups/common-config-*.yaml
  assert_file_exists "${CK8S_CONFIG_PATH}"/backups/sc-config-*.yaml
  assert_file_exists "${CK8S_CONFIG_PATH}"/backups/wc-config-*.yaml

  assert_file_exists "${CK8S_CONFIG_PATH}"/backups/common-default-*.yaml
  assert_file_exists "${CK8S_CONFIG_PATH}"/backups/sc-default-*.yaml
  assert_file_exists "${CK8S_CONFIG_PATH}"/backups/wc-default-*.yaml
}
