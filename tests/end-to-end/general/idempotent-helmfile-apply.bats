#!/usr/bin/env bats

# bats file_tags=idempotent-apply

setup_file() {
  # for --separate-stderr argument on 'run'
  bats_require_minimum_version 1.11.1

  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"
  load_assert
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

_apply() {
  local -r cluster="${1}"
  ck8s ops helmfile "${cluster}" apply --concurrency="$(nproc)" --suppress-diff
}

@test "SC helmfile apply is idempotent" {
  _apply sc

  run --separate-stderr bash -eo pipefail -c "ck8s ops helmfile sc diff --concurrency=$(nproc) --output json | sed -n '/^\[/p' | jq -s 'reduce .[] as \$item (0; . + (\$item | length))'"
  assert_success
  assert_output "0"
}

@test "WC helmfile apply is idempotent" {
  _apply wc

  run --separate-stderr bash -eo pipefail -c "ck8s ops helmfile wc diff --concurrency=$(nproc) --output json | sed -n '/^\[/p' | jq -s 'reduce .[] as \$item (0; . + (\$item | length))'"
  assert_success
  assert_output "0"
}
