#!/usr/bin/env bats

# Tests Gatekeeper policies

# Setup user-demo image
setup_file() {
  load "../common/lib"
  load "../common/lib/harbor"

  common_setup

  harbor.load_env gatekeeper-policies
  harbor.setup_project
  harbor.setup_user_demo_image

  export user_demo_image
}

setup() {
  load "../common/lib"

  common_setup
}

@test "gatekeeper policies has prepared image" {
  docker pull "${user_demo_image}"
}

# Teardown user-demo image
teardown_file() {
  load "../common/lib"
  load "../common/lib/harbor"

  common_setup

  harbor.teardown_project
}
