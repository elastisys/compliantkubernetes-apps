#!/usr/bin/env bats

# Generated from tests/unit/validate/template.bats.gotmpl

# bats file_tags=static,citycloud

setup_file() {
  # Not supported right now, might be able to leverage env.cache with some adaptions
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true

  load "../../common/lib"
  load "../../common/lib/env"
  load "../../common/lib/gpg"

  gpg.setup
  env.setup

  env.init prod citycloud kubespray
}

setup() {
  load "../../common/lib"
  load "script"

  common_setup
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "configuration is valid - kubespray:citycloud:prod - service cluster" {
  run ck8s validate sc <<< $'y\n'

  assert_success
}

@test "configuration is valid - kubespray:citycloud:prod - workload cluster" {
  run ck8s validate wc <<< $'y\n'

  assert_success
}

@test "configuration is invalid - kubespray:citycloud:prod - service cluster" {
  run yq_set 'sc' '.global.baseDomain' '"this is not a valid hostname"'
  run ck8s validate sc <<< $'y\n'

  assert_output --partial 'global.baseDomain'
}

@test "configuration is invalid - kubespray:citycloud:prod - workload cluster" {
  run yq_set 'wc' '.global.baseDomain' '"this is not a valid hostname"'
  run ck8s validate wc <<< $'y\n'

  assert_output --partial '"this is not a valid hostname"'
}

@test "manifests are valid - kubespray:citycloud:prod - service cluster" {
  run helmfile_template_kubeconform service_cluster

  assert_success
}

@test "manifests are valid - kubespray:citycloud:prod - workload cluster" {
  run helmfile_template_kubeconform workload_cluster

  assert_success
}
