#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/opensearch/opensearch-dashboards.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown "${ROOT}/tests/end-to-end/opensearch/opensearch-dashboards.cy.js"
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
