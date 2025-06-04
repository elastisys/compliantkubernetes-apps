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

declare -a clusters=("sc" "wc")

for cluster in "${clusters[@]}"; do
  bats_test_function \
    --description "${cluster^^} apps checks should pass" \
    -- apps_checks "${cluster}"
done

apps_checks() {
  local -r cluster="${1}"
  run ck8s test "${cluster}" apps
  assert_success
}
