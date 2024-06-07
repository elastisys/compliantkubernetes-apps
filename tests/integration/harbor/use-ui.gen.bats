#!/usr/bin/env bats

# bats file_tags=general,harbor,use-ui

setup_file() {
  load "../../bats.lib.bash"

  auto_setup sc app=cert-manager app=dex app=harbor app=ingress-nginx app=node-local-dns
  cypress_setup "${ROOT}/tests/integration/harbor/use-ui.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  load "../../bats.lib.bash"

  cypress_teardown "${ROOT}/tests/integration/harbor/use-ui.cy.js"
  auto_teardown
}

@test "harbor ui can create project" {
  cypress_test "harbor ui can create project"
}

@test "harbor ui can create system robot account" {
  cypress_test "harbor ui can create system robot account"
}

@test "harbor ui can delete system robot account" {
  cypress_test "harbor ui can delete system robot account"
}

@test "harbor ui can create project robot account" {
  cypress_test "harbor ui can create project robot account"
}

@test "harbor ui can delete project robot account" {
  cypress_test "harbor ui can delete project robot account"
}

@test "harbor ui can delete project" {
  cypress_test "harbor ui can delete project"
}
