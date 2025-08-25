#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/grafana/admin-promotion-ops.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "ops grafana user promotion admin demotes + promotes admin@example.com to Admin" {
  cypress_test "ops grafana user promotion admin demotes + promotes admin@example.com to Admin"
}
