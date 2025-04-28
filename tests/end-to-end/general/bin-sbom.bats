#!/usr/bin/env bats

# bats file_tags=bin-sbom

sbom_backup=$(mktemp --suffix=-sbom.json)

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_file

  cp "${ROOT}/docs/sbom.json" "${sbom_backup}"

  with_kubeconfig sc

  export CK8S_AUTO_APPROVE=true
  velero_version=$(ck8s sbom get velero | yq '.version')
}

teardown() {
  mv "${sbom_backup}" "${ROOT}/docs/sbom.json"
}

@test "ck8s sbom requires CK8S_CONFIG_PATH" {
  CK8S_CONFIG_PATH="" run ck8s sbom
  assert_failure
  assert_output --partial "Missing CK8S_CONFIG_PATH"
}

@test "ck8s sbom should show usage if no command is given" {
  run ck8s sbom
  assert_failure
  assert_output --partial "COMMANDS:"
}


@test "ck8s sbom get existing component" {
  run ck8s sbom get velero
  assert_success
  assert_output --partial '"name": "velero"'
}

@test "ck8s sbom get non-existing component" {
  run ck8s sbom get non-existing
  assert_failure
}

@test "ck8s sbom add component with unsupported key" {
  run ck8s sbom add velero "${velero_version}" unsupported-key '{"name": "test", "value": "test"}'
  assert_failure
  assert_output --partial 'unsupported key'
}

@test "ck8s sbom add component properties with correct object format" {
  run ck8s sbom add velero "${velero_version}" properties '{"name": "test", "value": "test"}'
  assert_success
  assert_output --partial 'Updated properties'
}

@test "ck8s sbom add component properties with incorrect object format" {
  CK8S_AUTO_APPROVE=false
  run ck8s sbom add velero "${velero_version}" properties '{"unsupported-key-name": "test", "unsupported-value": "test"}' <<< "y"
  assert_failure
  assert_output --partial 'Validation failed:'
}

# TODO: change this if generate command is changed to not require GITHUB_TOKEN
@test "ck8s sbom generate requires GITHUB_TOKEN" {
  GITHUB_TOKEN="" run ck8s sbom generate
  assert_failure
  assert_output --partial "Missing GITHUB_TOKEN"
}
