#!/usr/bin/env bats

# bats file_tags=ingress

setup_file() {
  # for dynamically registering tests using `bats_test_function`
  bats_require_minimum_version 1.11.1

  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export CK8S_AUTO_APPROVE="true"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

declare -a _clusters=("sc" "wc")

for _cluster in "${_clusters[@]}"; do
  bats_test_function \
    --description "${_cluster^^} ingress status should be OK" \
    -- ingress_should_be_ok "${_cluster}"
done

ingress_should_be_ok() {
  local -r cluster="${1}"
  run ck8s test "${cluster}" ingress
  assert_success
}
