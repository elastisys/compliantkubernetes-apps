#!/usr/bin/env bats

# Generated from tests/unit/templates/bin-init.bats.gotmpl

# bats file_tags=static,bin:init,elastx

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init elastx capi dev
}

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_assert
  load_file
  load "../templates/bin-init.bash"

  env.private
}

teardown() {
  env.teardown
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "init is successful - elastx:capi:dev" {
  test_init_successful
}

@test "init is idempotent - elastx:capi:dev" {
  test_init_idempotent
}
