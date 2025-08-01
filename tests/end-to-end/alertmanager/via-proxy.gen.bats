#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/alertmanager/via-proxy.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "workload cluster alertmanager can be accessed via kubectl proxy" {
  cypress_test "workload cluster alertmanager can be accessed via kubectl proxy"
}

@test "service cluster alertmanager can be accessed via kubectl proxy" {
  cypress_test "service cluster alertmanager can be accessed via kubectl proxy"
}
