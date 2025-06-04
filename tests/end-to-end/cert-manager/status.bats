#!/usr/bin/env bats

# bats file_tags=cert-manager

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

declare -a clusters=("sc" "wc")

for cluster in "${clusters[@]}"; do
  bats_test_function \
    --description "${cluster^^} cert-manager status should be OK" \
    -- cert_manager_should_be_ok "${cluster}"
done

cert_manager_should_be_ok() {
  local -r cluster="${1}"
  run ck8s test "${cluster}" cert-manager
  assert_success
}
