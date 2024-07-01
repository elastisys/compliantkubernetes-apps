#!/usr/bin/env bats

# Generated from tests/unit/bin/init/template.bats.gotmpl

# bats file_tags=static,bin:init,safespring

setup_file() {
  load "../../../common/lib"
  load "../../../common/lib/env"
  load "../../../common/lib/gpg"

  gpg.setup
  env.setup

  env.init prod safespring capi
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

@test "init is successful - capi:safespring:prod" {
  test_init_successful
}

@test "init is idempotent - capi:safespring:prod" {
  test_init_idempotent
}