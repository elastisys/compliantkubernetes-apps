#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/harbor-authentication.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  load "../../bats.lib.bash"

  cypress_teardown "${ROOT}/tests/end-to-end/harbor-authentication.cy.js"
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
