#!/usr/bin/env bats

# bats file_tags=general,harbor,dex-auth

setup_file() {
  load "../../bats.lib.bash"

  auto_setup sc app=cert-manager app=dex app=harbor app=ingress-nginx app=node-local-dns
  cypress_setup "${ROOT}/tests/integration/harbor/dex-auth.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  load "../../bats.lib.bash"

  cypress_teardown "${ROOT}/tests/integration/harbor/dex-auth.cy.js"
  auto_teardown
}

@test "harbor dex auth can login via static admin user" {
  cypress_test "harbor dex auth can login via static admin user"
}

@test "harbor dex auth can login via static dex user" {
  cypress_test "harbor dex auth can login via static dex user"
}

@test "harbor dex auth promote static dex user to admin" {
  cypress_test "harbor dex auth promote static dex user to admin"
}
