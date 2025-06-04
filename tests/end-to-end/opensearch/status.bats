#!/usr/bin/env bats

# bats file_tags=opensearch

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export CK8S_AUTO_APPROVE="true"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

@test "SC opensearch status should be OK" {
  run ck8s test sc opensearch
  assert_success
}
