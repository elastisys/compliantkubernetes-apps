#!/usr/bin/env bats

# bats file_tags=general,bin:diagnostics

setup_file() {
  load "../../common/lib"

  common_setup

  with_kubeconfig sc
}

setup() {
  load "../../common/lib"

  common_setup

  with_kubeconfig sc
}

@test "diagnostics - requires CK8S_CONFIG_PATH" {
  CK8S_CONFIG_PATH="" run ck8s diagnostics sc
  assert_failure
  assert_output --partial "Missing CK8S_CONFIG_PATH"
}

@test "diagnostics - creates diagnostics file" {
  run ck8s diagnostics sc
  assert_success

  file=$(find "${CK8S_CONFIG_PATH}"/diagnostics-*.log | sort -r | head -n 1)

  assert_file_exists "${file}"
  assert_file_contains "${file}" '"sops":'

  assert_file_contains <(sops -d "${file}") "<node>"
  assert_file_contains <(sops -d "${file}") "<deployment>"
  assert_file_contains <(sops -d "${file}") "<daemonset>"
  assert_file_contains <(sops -d "${file}") "<statefulset>"
  assert_file_contains <(sops -d "${file}") "<pod>"
  assert_file_contains <(sops -d "${file}") "<top>"
  assert_file_contains <(sops -d "${file}") "<helm>"
  assert_file_contains <(sops -d "${file}") "<cert>"
  assert_file_contains <(sops -d "${file}") "<challenge>"
  assert_file_contains <(sops -d "${file}") "<event>"
}
