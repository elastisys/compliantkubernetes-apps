#!/usr/bin/env bats

# bats file_tags=general,harbor,deploy

# Integration test: Harbor deployment

setup_file() {
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"
  load_common "local-cluster.bash"

  local_cluster.setup dev integration.dev-ck8s.com
  local_cluster.create single-node-cache

  local_cluster.configure_selfsigned

  ck8s ops helmfile sc apply --include-transitive-needs --output simple \
    -lapp=cert-manager \
    -lapp=dex \
    -lapp=harbor \
    -lapp=ingress-nginx \
    -lapp=node-local-dns
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_detik
}

teardown_file() {
  load "../../bats.lib.bash"
  load_common "local-cluster.bash"

  local_cluster.delete
  local_cluster.teardown
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
