#!/usr/bin/env bats

# Generated from tests/unit/bin/init/template.bats.gotmpl

# bats file_tags=static,bin:init,exoscale

setup_file() {
  load "../../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init exoscale kubespray dev
}

setup() {
  load "../../../bats.lib.bash"
  load_common "env.bash"
  load_assert
  load_file
  load "script"

  env.private
}

teardown() {
  env.teardown
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "init is successful - exoscale:kubespray:dev" {
  test_init_successful
}

@test "init is idempotent - exoscale:kubespray:dev" {
  test_init_idempotent
}
