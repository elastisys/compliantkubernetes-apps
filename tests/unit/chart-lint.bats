#!/usr/bin/env bats

# bats file_tags=static,general

# TODO: Change these to validate without helmfile so we can verify that the charts themselves render without an environment

setup_file() {
  load "../common/lib"
  load "../common/lib/env"
  load "../common/lib/gpg"

  env.setup
  gpg.setup

  common_setup

  env.init prod baremetal
}

teardown_file() {
  env.teardown
  gpg.teardown
}

setup() {
  load "../common/lib"

  common_setup
}

@test "chart lint - apps sc" {
  run helmfile -e service_cluster -f "${ROOT}/helmfile/" lint

  assert_success
}

@test "chart lint - apps wc" {
  run helmfile -e workload_cluster -f "${ROOT}/helmfile/" lint

  assert_success
}

@test "chart lint - bootstrap sc" {
  run helmfile -e service_cluster -f "${ROOT}/bootstrap/namespaces/helmfile/" lint

  assert_success
}

@test "chart lint - bootstrap wc" {
  run helmfile -e workload_cluster -f "${ROOT}/bootstrap/namespaces/helmfile/" lint

  assert_success
}
