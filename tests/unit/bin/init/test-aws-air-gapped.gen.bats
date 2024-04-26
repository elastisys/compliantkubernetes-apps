#!/usr/bin/env bats

# Generated from tests/unit/bin/init/template.bats.gotmpl

# bats file_tags=static,bin:init,aws

setup_file() {
  # Not supported right now, might be able to leverage env.cache with some adaptions
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true

  load "../../../common/lib"
  load "../../../common/lib/env"
  load "../../../common/lib/gpg"

  gpg.setup
  env.setup

  env.init air-gapped aws
  env.cache_create
}

setup() {
  load "../../../common/lib"
  load "../../../common/lib/env"
  load "script"

  common_setup
  env.cache_restore
}

teardown_file() {
  env.cache_delete
  env.teardown
  gpg.teardown
}

@test "init is successful - aws:air-gapped" {
  test_init_successful
}

@test "init is idempotent - aws:air-gapped" {
  test_init_idempotent
}
