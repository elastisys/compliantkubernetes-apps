#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/alertmanager/expected-alerts.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "workload cluster alertmanager should validate all alert names are from expected set" {
  cypress_test "workload cluster alertmanager should validate all alert names are from expected set"
}

@test "service cluster alertmanager should validate all alert names are from expected set" {
  cypress_test "service cluster alertmanager should validate all alert names are from expected set"
}
