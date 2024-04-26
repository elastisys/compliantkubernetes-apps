#!/usr/bin/env bats

setup_file() {
  load "../common/lib"

  cypress_setup "${ROOT}/tests/end-to-end/harbor-authentication.cy.js"
}

setup() {
  load "../common/lib"

  common_setup
}

@test "harbor authentication can login via static admin user" {
  cypress_test "harbor authentication can login via static admin user"
}

@test "harbor authentication can login via static dex user" {
  cypress_test "harbor authentication can login via static dex user"
}

@test "harbor authentication promote static dex user to admin" {
  cypress_test "harbor authentication promote static dex user to admin"
}

teardown_file() {
  load "../common/lib"

  cypress_teardown "${ROOT}/tests/end-to-end/harbor-authentication.cy.js"
}
