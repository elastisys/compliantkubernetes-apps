#!/usr/bin/env bats

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"
  load_assert

  env.setup
  gpg.setup

  env.init baremetal kubespray prod
}

teardown() {
  env.teardown
  gpg.teardown
}

@test "issue 2172 - init should preserve empty override map" {
  yq.set wc '.user.constraints.default.allow' '{}'
  ck8s init wc

  assert_equal "$(yq.dig wc '.user.constraints.default.allow')" "{}"
}
