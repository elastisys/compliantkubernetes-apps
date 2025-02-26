#!/usr/bin/env bats

# bats file_tags=static,general,bin:upgrade

setup_file() {
  load "../../bats.lib.bash"
  load_common "gpg.bash"

  gpg.setup
}

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "git-version.bash"
  load_common "yq.bash"
  load_assert
  load_file
  load_mock

  gitversion.setup_mocks

  env.setup
  env.init baremetal kubespray prod
}

teardown() {
  env.teardown
}

teardown_file() {
  gpg.teardown
}

@test "it works" {
  gitversion.mock_static "v0.42.0"

  run ck8s init sc
  assert_success

  run ck8s version config
  assert_success
  assert_output --partial "v0.42"

  gitversion.mock_upgrade "v0.42.0" "v0.43.0"

  run ck8s upgrade sc "v0.43" prepare
  assert_success

  gitversion.mock_static "v0.43.0"

  run ck8s version config
  assert_success
  assert_output --partial "v0.43"
}
