#!/usr/bin/env bats

# Generated from tests/unit/validate/template.bats.gotmpl

# bats file_tags=static,validate,elastx,prod

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init prod elastx
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_common "env.bash"
  load_common "yq.bash"
  load "script"

  env.private
}

teardown() {
  env.teardown
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "configuration is valid - elastx:prod - service cluster" {
  run ck8s validate sc <<< $'y\n'

  assert_success
}

@test "configuration is valid - elastx:prod - workload cluster" {
  run ck8s validate wc <<< $'y\n'

  assert_success
}

@test "configuration is invalid - elastx:prod - service cluster" {
  run yq.set 'sc' '.global.baseDomain' '"this is not a valid hostname"'
  run ck8s validate sc <<< $'y\n'

  assert_output --partial 'global.baseDomain'
}

@test "configuration is invalid - elastx:prod - workload cluster" {
  run yq.set 'wc' '.global.baseDomain' '"this is not a valid hostname"'
  run ck8s validate wc <<< $'y\n'

  assert_output --partial '"this is not a valid hostname"'
}

@test "manifests are valid - elastx:prod - service cluster" {
  run helmfile_template_kubeconform service_cluster

  assert_success
}

@test "manifests are valid - elastx:prod - workload cluster" {
  run helmfile_template_kubeconform workload_cluster

  assert_success
}
