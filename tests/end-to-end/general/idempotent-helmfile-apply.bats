#!/usr/bin/env bats

# bats file_tags=idempotent-apply

setup_file() {
  # for --separate-stderr argument on 'run'
  bats_require_minimum_version 1.11.1

  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"
  load_assert

  load_common "git.bash"

  if git.is_modified "$CK8S_CONFIG_PATH"; then
    fail "Fatal: CK8S_CONFIG_PATH (${CK8S_CONFIG_PATH}) is tracked in a git repository and has uncommitted changes. Please commit or stash your changes and be mindful that this test suite will 'apply' all of the application stacks in both the SC and the WC clusters."
  fi
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

@test "SC helmfile apply is idempotent" {
  # double apply as per the QA checklist instructions
  _apply sc
  _apply sc

  run --separate-stderr bash -c "ck8s ops helmfile sc diff --output json | sed -n '/^\[/p' | jq -s 'reduce .[] as \$item (0; . + (\$item | length))'"
  assert_output "0"
}

@test "WC helmfile apply is idempotent" {
  # double apply as per the QA checklist instructions
  _apply wc
  _apply wc

  run --separate-stderr bash -c "ck8s ops helmfile wc diff --output json | sed -n '/^\[/p' | jq -s 'reduce .[] as \$item (0; . + (\$item | length))'"
  assert_output "0"
}

_apply() {
  local -r cluster="${1}"
  ck8s ops helmfile "${cluster}" apply --concurrency="$(nproc)" --suppress-diff
}
