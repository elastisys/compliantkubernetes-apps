#!/usr/bin/env bats

setup_file() {
  load "../common/lib/local-cluster"

  local_cluster.setup dev integration.dev-ck8s.com
  local_cluster.create single-node-cache
}

teardown_file() {
  load "../common/lib/local-cluster"

  local_cluster.teardown
  local_cluster.delete
}

setup() {
  load "../common/lib"

  common_setup
}

helm_status() {
  helm -n "${1}" status "${2}" -oyaml | yq4 '.info.status'
}

@test "local cluster has kubeconfigs" {
  assert [ -f "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml" ]
  assert [ -f "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml" ]
}

@test "local cluster has ready nodes" {
  run kubectl get no apps-tests-control-plane '-ojsonpath={.status.conditions[?(@.type=="Ready")].status}'
  assert_output "True"
  run kubectl get no apps-tests-worker '-ojsonpath={.status.conditions[?(@.type=="Ready")].status}'
  assert_output "True"
}

@test "local cluster has running calico system" {
  with_kubeconfig sc
  with_namespace calico-system

  test_deployment calico-kube-controllers
  test_daemonset calico-node
  test_deployment calico-typha
  test_daemonset csi-node-driver
}

@test "local cluster has installed minio" {
  run helm_status minio-system minio
  assert_output "deployed"
}

@test "local cluster has running minio" {
  with_kubeconfig sc

  with_namespace minio-system
}

@test "local cluster has installed tigera operator" {
  run helm_status tigera-operator tigera
  assert_output "deployed"
}

@test "local cluster has running tigera operator" {
  with_kubeconfig sc

  with_namespace tigera-operator
  test_deployment tigera-operator
}
