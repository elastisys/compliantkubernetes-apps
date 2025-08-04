#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/opensearch/dashboards.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "opensearch dashboards open the audit user dashboard" {
  cypress_test "opensearch dashboards open the audit user dashboard"
}

@test "opensearch dashboards test kubeaudit index" {
  cypress_test "opensearch dashboards test kubeaudit index"
}

@test "opensearch dashboards test kubernetes index" {
  cypress_test "opensearch dashboards test kubernetes index"
}

@test "opensearch dashboards test other index" {
  cypress_test "opensearch dashboards test other index"
}

@test "opensearch dashboards test authlog index" {
  cypress_test "opensearch dashboards test authlog index"
}

@test "Verify indices are managed in ISM UI " {
  cypress_test "Verify indices are managed in ISM UI "
}

@test "Verify snapshot policy exists via search " {
  cypress_test "Verify snapshot policy exists via search "
}

@test "Create a manual snapshot should take a snapshot successfully" {
  cypress_test "Create a manual snapshot should take a snapshot successfully"
}
