#!/usr/bin/env bats

# bats file_tags=static,general,opa

setup() {
  load "../../bats.lib.bash"
  load_assert
}

@test "opa gatekeeper policies is valid" {
  run opa test -v "${CHARTS}/gatekeeper/templates/policies/"

  assert_success
}
