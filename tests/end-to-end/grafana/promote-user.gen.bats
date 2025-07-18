#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/grafana/promote-user.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "grafana user promotion can promote a static user to admin" {
  cypress_test "grafana user promotion can promote a static user to admin"
}
