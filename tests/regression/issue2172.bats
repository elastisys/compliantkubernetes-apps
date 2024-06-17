#!/usr/bin/env bats

# bats file_tags=regression,bin:init

setup() {
  load "../common/lib"
  load "../common/lib/env"
  env.setup
  env.init "dev" "baremetal"
  common_setup
}

teardown() {
  env.teardown
}

@test "issue 2172 has not regressed" {
  run yq_set wc '.user.constraints.default.allow' '{}'
  run ck8s init wc
  assert_equal "$(yq_dig wc '.user.constraints.default.allow')" "{}"
}
