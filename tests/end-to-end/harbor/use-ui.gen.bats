#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/harbor/use-ui.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown "${ROOT}/tests/end-to-end/harbor/use-ui.cy.js"
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
