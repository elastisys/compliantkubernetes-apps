#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/kubernetes/authentication-admin.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown "${ROOT}/tests/end-to-end/kubernetes/authentication-admin.cy.js"
}

@test "kubernetes authentication can login via static dex user" {
  cypress_test "kubernetes authentication can login via static dex user"
}
