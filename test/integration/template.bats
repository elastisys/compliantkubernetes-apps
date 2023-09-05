#!/usr/bin/env bats

setup() {
  load "../common/lib"

  common_setup
}

@test "this is a template" {
  assert true
}
