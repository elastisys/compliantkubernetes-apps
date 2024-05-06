#!/usr/bin/env bats

# bats file_tags=static,general,chart-lint

# TODO: Change these to validate without helmfile so we can verify that the charts themselves render without an environment

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  env.setup
  gpg.setup

  env.init baremetal kubespray prod
}

teardown_file() {
  env.teardown
  gpg.teardown
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

@test "charts should follow linter - service cluster" {
  run helmfile -e service_cluster -f "${ROOT}/helmfile.d/" lint

  assert_success
}

@test "charts should follow linter - workload cluster" {
  run helmfile -e workload_cluster -f "${ROOT}/helmfile.d/" lint

  assert_success
}
