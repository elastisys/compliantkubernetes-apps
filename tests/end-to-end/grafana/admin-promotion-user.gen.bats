#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/grafana/admin-promotion-user.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "user grafana user promotion admin demotes + promotes dev@example.com to Admin" {
  cypress_test "user grafana user promotion admin demotes + promotes dev@example.com to Admin"
}
