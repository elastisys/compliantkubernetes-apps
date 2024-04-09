#!/usr/bin/env bats

# Generated from tests/unit/bin/init/template.bats.gotmpl

# bats file_tags=static,bin:init,safespring

setup_file() {
  load "../../../common/lib"
  load "../../../common/lib/env"
  load "../../../common/lib/gpg"

  gpg.setup
  env.setup

  env.init dev safespring
}

setup() {
  load "../../../common/lib"
  load "../../../common/lib/env"
  load "script"

  common_setup
  env.private
}

teardown() {
  env.teardown
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "init is successful - safespring:dev" {
  test_init_successful
}

@test "init is idempotent - safespring:dev" {
  test_init_idempotent
}
