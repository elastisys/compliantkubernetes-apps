#!/usr/bin/env bats

# bats file_tags=static,general,opa

setup() {
  load "../common/lib"

  CK8S_CONFIG_PATH="$(mktemp --directory)"
  export CK8S_CONFIG_PATH

  common_setup
}

teardown() {
  rm -rf "${CK8S_CONFIG_PATH}"
}

@test "opa gatekeeper policies - opa test" {
  run opa test -v "${ROOT}/helmfile.d/charts/gatekeeper/templates/policies/"

  assert_success
}
