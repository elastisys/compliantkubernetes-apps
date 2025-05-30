#!/usr/bin/env bats

# bats file_tags=apps

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
    --description "${_cluster^^} apps checks should pass" \
    -- apps_checks "${_cluster}"
done

apps_checks() {
  local -r cluster="${1}"
  run ck8s test "${cluster}" apps
  assert_success
}
