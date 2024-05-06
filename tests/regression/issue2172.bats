#!/usr/bin/env bats

# bats file_tags=regression,bin:init

setup_file() {
  load "../bats.lib.bash"
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

@test "issue 2172 has not regressed" {
  run yq_set wc '.user.constraints.default.allow' '{}'
  run ck8s init wc
  assert_equal "$(yq_dig wc '.user.constraints.default.allow')" "{}"
}
