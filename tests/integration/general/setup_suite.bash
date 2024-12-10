#!/usr/bin/env bash

setup_suite() {
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"
  load_common "local-cluster.bash"

  local_cluster.setup dev test.dev-ck8s.com
  local_cluster.create sc single-node-cache
}

teardown_suite() {
  local_cluster.delete sc
  local_cluster.teardown
}
