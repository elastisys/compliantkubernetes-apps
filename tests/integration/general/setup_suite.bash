setup_suite() {
  load "../../bats.lib.bash"
  load_common "local-cluster.bash"

  export CK8S_AUTO_APPROVE="true"

  local_cluster.setup dev test.dev-ck8s.com
  local_cluster.create single-node-cache
}

teardown_suite() {
  local_cluster.delete
  local_cluster.teardown
}
