#!/usr/bin/env bats

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
}

# bats file_tags=opensearch

setup() {
  load "../../bats.lib.bash"
  load_assert
  with_kubeconfig sc
}

@test "Check if OpenSearch Curator job exists" {
  run kubectl -n opensearch-system get job -lapp.kubernetes.io/name=opensearch-curator
  assert_success
}
