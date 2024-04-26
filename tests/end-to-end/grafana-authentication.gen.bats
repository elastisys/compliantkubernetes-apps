#!/usr/bin/env bats

setup_file() {
  load "../common/lib"

  cypress_setup "${ROOT}/tests/end-to-end/grafana-authentication.cy.js"
}

setup() {
  load "../common/lib"

  common_setup
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

teardown_file() {
  load "../common/lib"

  cypress_teardown "${ROOT}/tests/end-to-end/grafana-authentication.cy.js"
}
