#!/usr/bin/env bats

setup_file() {
  load "../common/lib"

  cypress_setup "${ROOT}/tests/end-to-end/grafana-datasources.cy.js"
}

setup() {
  load "../common/lib"

  common_setup
}

@test "grafana admin datasources has prometheus" {
  cypress_test "grafana admin datasources has prometheus"
}

@test "grafana admin datasources has thanos all" {
  cypress_test "grafana admin datasources has thanos all"
}

@test "grafana admin datasources has thanos sc" {
  cypress_test "grafana admin datasources has thanos sc"
}

@test "grafana admin datasources has thanos wc" {
  cypress_test "grafana admin datasources has thanos wc"
}

@test "grafana dev datasources has service cluster" {
  cypress_test "grafana dev datasources has service cluster"
}

@test "grafana dev datasources has workload cluster" {
  cypress_test "grafana dev datasources has workload cluster"
}

teardown_file() {
  load "../common/lib"

  cypress_teardown "${ROOT}/tests/end-to-end/grafana-datasources.cy.js"
}
