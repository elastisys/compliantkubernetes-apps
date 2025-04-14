#!/usr/bin/env bats

# bats file_tags=general,local-clusters

setup_file() {
  load "../../bats.lib.bash"
  load_common "local-cluster.bash"

  export CK8S_AUTO_APPROVE="true"

  local_cluster.setup dev test.dev-ck8s.com
  local_cluster.create sc single-node-cache
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_detik
}

teardown_file() {
  local_cluster.delete sc
  local_cluster.teardown
}

helm_status() {
  helm -n "${1}" status "${2}" -oyaml | yq4 '.info.status'
}

@test "local cluster has created kubeconfig" {
  assert [ -f "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml" ]
}

@test "local cluster has ready nodes" {
  run "${ROOT}/bin/ck8s" ops kubectl sc get no apps-tests-sc-control-plane '-ojsonpath={.status.conditions[?(@.type=="Ready")].status}'
  assert_output "True"
  run "${ROOT}/bin/ck8s" ops kubectl sc get no apps-tests-sc-worker '-ojsonpath={.status.conditions[?(@.type=="Ready")].status}'
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
