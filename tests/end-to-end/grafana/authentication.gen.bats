#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/grafana/authentication.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "grafana admin authentication can login via static admin user" {
  cypress_test "grafana admin authentication can login via static admin user"
}

@test "grafana admin authentication can login via static dex user" {
  cypress_test "grafana admin authentication can login via static dex user"
}

@test "grafana dev authentication can login via static admin user" {
  cypress_test "grafana dev authentication can login via static admin user"
}

@test "grafana dev authentication can login via static dex user" {
  cypress_test "grafana dev authentication can login via static dex user"
}
