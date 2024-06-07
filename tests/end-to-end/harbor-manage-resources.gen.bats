#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/harbor-manage-resources.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  load "../../bats.lib.bash"

  cypress_teardown "${ROOT}/tests/end-to-end/harbor-manage-resources.cy.js"
}

@test "harbor manage resources can create project" {
  cypress_test "harbor manage resources can create project"
}

@test "harbor manage resources can create system robot account" {
  cypress_test "harbor manage resources can create system robot account"
}

@test "harbor manage resources can delete system robot account" {
  cypress_test "harbor manage resources can delete system robot account"
}

@test "harbor manage resources can create project robot account" {
  cypress_test "harbor manage resources can create project robot account"
}

@test "harbor manage resources can delete project robot account" {
  cypress_test "harbor manage resources can delete project robot account"
}

@test "harbor manage resources can delete project" {
  cypress_test "harbor manage resources can delete project"
}
