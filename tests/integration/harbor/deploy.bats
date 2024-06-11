#!/usr/bin/env bats

# bats file_tags=harbor,deploy

# Integration test: Harbor deployment

setup_file() {
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"

  auto_setup sc app=cert-manager app=dex app=harbor app=ingress-nginx app=node-local-dns
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_detik
}

teardown_file() {
  load "../../bats.lib.bash"

  auto_teardown
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
