#!/usr/bin/env bats

# bats file_tags=harbor,dex-auth

setup_file() {
  load "../../bats.lib.bash"
  load "setup_suite.bash"

  setup_harbor

  cypress_setup "${ROOT}/tests/integration/harbor/dex-auth.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  teardown_harbor
  cypress_teardown "${ROOT}/tests/integration/harbor/dex-auth.cy.js"
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
