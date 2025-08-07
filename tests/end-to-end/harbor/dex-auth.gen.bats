#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/harbor/dex-auth.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "harbor dex auth can login via static admin user" {
  cypress_test "harbor dex auth can login via static admin user"
}

@test "harbor dex auth can login via static dex user" {
  cypress_test "harbor dex auth can login via static dex user"
}

@test "harbor dex auth can promote static dex user to admin" {
  cypress_test "harbor dex auth can promote static dex user to admin"
}
