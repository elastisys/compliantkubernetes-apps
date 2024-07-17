#!/usr/bin/env bats

# bats file_tags=harbor,deploy

# Integration test: Harbor deployment

setup_file() {
  load "../../bats.lib.bash"
  load "setup_suite.bash"

  setup_harbor
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_detik
}

teardown_file() {
  teardown_harbor
}

@test "harbor has been deployed" {
  with_kubeconfig sc
  with_namespace harbor

  test_deployment harbor-core
  test_deployment harbor-exporter
  test_deployment harbor-jobservice
  test_deployment harbor-portal
  test_deployment harbor-registry

  test_statefulset harbor-database
  test_statefulset harbor-redis
  test_statefulset harbor-trivy
}
