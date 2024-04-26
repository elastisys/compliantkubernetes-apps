#!/usr/bin/env bats

setup_file() {
  load "../common/lib"

  cypress_setup "${ROOT}/tests/end-to-end/harbor-manage-resources.cy.js"
}

setup() {
  load "../common/lib"

  common_setup
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

teardown_file() {
  load "../common/lib"

  cypress_teardown "${ROOT}/tests/end-to-end/harbor-manage-resources.cy.js"
}
