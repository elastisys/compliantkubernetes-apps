#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/netpol/netpol.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "workload cluster network policies are not dropping any packets from workloads" {
  cypress_test "workload cluster network policies are not dropping any packets from workloads"
}

@test "workload cluster network policies are not dropping any packets to workloads" {
  cypress_test "workload cluster network policies are not dropping any packets to workloads"
}

@test "service cluster network policies are not dropping any packets from workloads" {
  cypress_test "service cluster network policies are not dropping any packets from workloads"
}

@test "service cluster network policies are not dropping any packets to workloads" {
  cypress_test "service cluster network policies are not dropping any packets to workloads"
}
