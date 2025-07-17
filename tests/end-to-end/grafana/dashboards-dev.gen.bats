#!/usr/bin/env bats

setup_file() {
  load "../../bats.lib.bash"

  cypress_setup "${ROOT}/tests/end-to-end/grafana/dashboards-dev.cy.js"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

teardown_file() {
  cypress_teardown
}

@test "grafana dev dashboards open the Backup status dashboard" {
  cypress_test "grafana dev dashboards open the Backup status dashboard"
}

@test "grafana dev dashboards open the Trivy Operator Dashboard" {
  cypress_test "grafana dev dashboards open the Trivy Operator Dashboard"
}

@test "grafana dev dashboards open the NetworkPolicy Dashboard" {
  cypress_test "grafana dev dashboards open the NetworkPolicy Dashboard"
}

@test "grafana dev dashboards open the Kubernetes cluster status dashboard" {
  cypress_test "grafana dev dashboards open the Kubernetes cluster status dashboard"
}

@test "grafana dev dashboards open the Gatekeeper dashboard" {
  cypress_test "grafana dev dashboards open the Gatekeeper dashboard"
}

@test "grafana dev dashboards open the NGINX Ingress controller dashboard" {
  cypress_test "grafana dev dashboards open the NGINX Ingress controller dashboard"
}

@test "grafana dev dashboards open the Falco dashboard" {
  cypress_test "grafana dev dashboards open the Falco dashboard"
}
