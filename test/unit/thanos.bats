#!/usr/bin/env bats

setup() {
  load "../common/lib"

  common_setup

  skip_on_disabled sc thanos

  with_kubeconfig sc
  with_namespace thanos
}

@test "thanos-query pods are ready" {
  skip_on_disabled sc thanos.query

  replicas="$(get sc thanos.query.replicaCount)"

  check_deployment thanos-query-query "${replicas}"
}

@test "thanos-query-frontend pods are ready" {
  skip_on_disabled sc thanos.query

  check_deployment thanos-query-query-frontend 1
}

@test "thanos-receiver-bucketweb pods are ready" {
  skip_on_disabled sc thanos.receiver

  check_deployment thanos-receiver-bucketweb 1
}

@test "thanos-receiver-compactor pods are ready" {
  skip_on_disabled sc thanos.receiver

  check_deployment thanos-receiver-compactor 1
}

@test "thanos-receiver-receive pods are ready" {
  skip_on_disabled sc thanos.receiver

  replicas="$(get sc thanos.receiver.replicaCount)"

  check_statefulset thanos-receiver-receive "${replicas}"
}

@test "thanos-receiver-receive-distributor pods are ready" {
  skip_on_disabled sc thanos.receiver

  check_deployment thanos-receiver-receive-distributor 1
}

@test "thanos-receiver-ruler pods are ready" {
  skip_on_disabled sc thanos.ruler

  replicas="$(get sc thanos.ruler.replicaCount)"

  check_statefulset thanos-receiver-ruler "${replicas}"
}

@test "thanos-receiver-storegateway pods are ready" {
  skip_on_disabled sc thanos.receiver

  check_statefulset thanos-receiver-storegateway 1
}
