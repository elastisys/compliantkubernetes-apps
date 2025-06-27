#!/usr/bin/env bats

# bats file_tags=scripts-sbom

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_file

  PATH=:${ROOT}/scripts/sbom:${PATH}

  export CK8S_AUTO_APPROVE=false
  export CK8S_SKIP_VALIDATION=false
  VELERO_CHART_LOCATION=helmfile.d/upstream/vmware-tanzu/velero
}

@test "sbom script should show usage if no command is given" {
  run sbom.bash
  assert_failure
  assert_output --partial "COMMANDS:"
}

@test "sbom script get existing component be successful" {
  run sbom.bash get "${VELERO_CHART_LOCATION}"
  assert_success
  assert_output --partial '"name": "velero"'
}

@test "sbom script get non-existing component should fail" {
  run sbom.bash get non-existing
  assert_failure
}

@test "sbom script get-charts should be successful" {
  run sbom.bash get-charts
  assert_success
  assert_output --partial "${VELERO_CHART_LOCATION}"
}

@test "sbom script get-containers should be successful" {
  run sbom.bash get-containers
  assert_success
}

@test "sbom script validate should be successful" {
  run sbom.bash validate
  assert_success
  assert_output --partial 'BOM validated successfully.'
}

@test "sbom script add component with unsupported key should fail" {
  run sbom.bash add "${VELERO_CHART_LOCATION}" unsupported-key "foo"
  assert_failure
  assert_output --partial 'unsupported key'
}

@test "sbom script add component with supported key properties should prompt" {
  run sbom.bash add "${VELERO_CHART_LOCATION}" properties "foo" "bar" <<<n
  assert_success
  assert_output --partial 'BOM validated successfully.'
  assert_output --partial 'Do you want to continue?'
}

@test "sbom script generate requires GITHUB_TOKEN" {
  GITHUB_TOKEN="" run sbom.bash generate
  assert_failure
  assert_output --partial "Missing GITHUB_TOKEN"
}

@test "sbom script update requires GITHUB_TOKEN" {
  GITHUB_TOKEN="" run sbom.bash update "${VELERO_CHART_LOCATION}"
  assert_failure
  assert_output --partial "Missing GITHUB_TOKEN"
}

@test "sbom script update with no change should be successful" {
  CK8S_SKIP_VALIDATION=true GITHUB_TOKEN="test" run sbom.bash update "${VELERO_CHART_LOCATION}"
  assert_success
  assert_output --partial "No change"
}

@test "sbom script diff with no change should be successful" {
  CK8S_SKIP_VALIDATION=true GITHUB_TOKEN="test" run sbom.bash diff
  assert_success
  assert_output --partial "No chart changes found"
}
