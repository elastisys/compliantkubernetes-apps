#!/usr/bin/env bats

setup_file() {
  load "../common/lib"

  cypress_setup "${ROOT}/tests/end-to-end/opensearch-dashboards.cy.js"
}

setup() {
  load "../common/lib"

  common_setup
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

teardown_file() {
  load "../common/lib"

  cypress_teardown "${ROOT}/tests/end-to-end/opensearch-dashboards.cy.js"
}
