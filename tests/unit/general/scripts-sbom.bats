#!/usr/bin/env bats

# bats file_tags=scripts-sbom

sbom_backup=$(mktemp --suffix=-sbom.json)

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_file

  cp "${ROOT}/docs/sbom.json" "${sbom_backup}"

  PATH=:${ROOT}/scripts/sbom:${PATH}

  export CK8S_AUTO_APPROVE=true
  VELERO_CHART="${ROOT}/helmfile.d/upstream/vmware-tanzu/velero/Chart.yaml"
  velero_version=$(yq '.version' "${VELERO_CHART}")
}

teardown() {
  mv "${sbom_backup}" "${ROOT}/docs/sbom.json"
}

@test "sbom script should show usage if no command is given" {
  run sbom.bash
  assert_failure
  assert_output --partial "COMMANDS:"
}

@test "sbom script get existing component" {
  run sbom.bash get velero
  assert_success
  assert_output --partial '"name": "velero"'
}

@test "sbom script get non-existing component" {
  run sbom.bash get non-existing
  assert_failure
}

@test "sbom script add component with unsupported key" {
  run sbom.bash add velero "${velero_version}" unsupported-key '{"name": "test", "value": "test"}'
  assert_failure
  assert_output --partial 'unsupported key'
}

@test "sbom script add component properties with correct object format" {
  run sbom.bash add velero "${velero_version}" properties '{"name": "test", "value": "test"}'
  assert_success
  assert_output --partial 'Updated properties'
}

@test "sbom script add component properties with incorrect object format should fail cyclonedx validation" {
  export CK8S_AUTO_APPROVE=false
  export CK8S_SKIP_VALIDATION=false
  run sbom.bash add velero "${velero_version}" properties '{"unsupported-key-name": "test", "unsupported-value": "test"}' <<<n
  assert_output --partial 'Validation failed:'
  assert_output --regexp 'Required properties .* are not present'
}

# TODO: change this if generate command is changed to not require GITHUB_TOKEN
@test "sbom script generate requires GITHUB_TOKEN" {
  GITHUB_TOKEN="" run sbom.bash generate
  assert_failure
  assert_output --partial "Missing GITHUB_TOKEN"
}

@test "sbom script validate should be successful" {
  run sbom.bash validate
  assert_success
  assert_output --partial "BOM validated successfully."
}
