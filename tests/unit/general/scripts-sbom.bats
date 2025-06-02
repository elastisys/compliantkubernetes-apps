#!/usr/bin/env bats

# bats file_tags=scripts-sbom

sbom_backup=$(mktemp --suffix=-sbom.json)
velero_chart_backup=$(mktemp --suffix=-velero-chart.json)

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_file

  PATH=:${ROOT}/scripts/sbom:${PATH}

  export CK8S_AUTO_APPROVE=false
  export CK8S_SKIP_VALIDATION=false
  VELERO_CHART_RELATIVE_FOLDER=helmfile.d/upstream/vmware-tanzu/velero
  VELERO_CHART="${ROOT}/${VELERO_CHART_RELATIVE_FOLDER}/Chart.yaml"

  cp "${ROOT}/docs/sbom.json" "${sbom_backup}"
  cp "${VELERO_CHART}" "${velero_chart_backup}"
}

teardown() {
  mv --force "${sbom_backup}" "${ROOT}/docs/sbom.json"
  mv --force "${velero_chart_backup}" "${VELERO_CHART}"
}

@test "sbom script should show usage if no command is given" {
  run sbom.bash
  assert_failure
  assert_output --partial "COMMANDS:"
}

@test "sbom script get existing component" {
  run sbom.bash get "${VELERO_CHART_RELATIVE_FOLDER}"
  assert_success
  assert_output --partial '"name": "velero"'
}

@test "sbom script get non-existing component" {
  run sbom.bash get non-existing
  assert_failure
}

@test "sbom script validate should be successful" {
  run sbom.bash validate
  assert_success
  assert_output --partial 'BOM validated successfully.'
}

@test "sbom script add component with unsupported key" {
  run sbom.bash add "${VELERO_CHART_RELATIVE_FOLDER}" unsupported-key "foo"
  assert_failure
  assert_output --partial 'unsupported key'
}

@test "sbom script add component with supported key properties" {
  export CK8S_AUTO_APPROVE=true
  run sbom.bash add "${VELERO_CHART_RELATIVE_FOLDER}" properties "foo" "bar"
  assert_success
  assert_output --partial 'Updated properties'
}

@test "sbom script generate requires GITHUB_TOKEN" {
  GITHUB_TOKEN="" run sbom.bash generate
  assert_failure
  assert_output --partial "Missing GITHUB_TOKEN"
}

@test "sbom script update requires GITHUB_TOKEN" {
  GITHUB_TOKEN="" run sbom.bash update "${VELERO_CHART_RELATIVE_FOLDER}"
  assert_failure
  assert_output --partial "Missing GITHUB_TOKEN"
}

@test "sbom script update with no change should work" {
  export CK8S_SKIP_VALIDATION=true
  GITHUB_TOKEN="test" run sbom.bash update "${VELERO_CHART_RELATIVE_FOLDER}"
  assert_success
  assert_output --partial "No change"
}
