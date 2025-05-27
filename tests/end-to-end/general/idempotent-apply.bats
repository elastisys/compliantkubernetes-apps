#!/usr/bin/env bats

# bats file_tags=idempotent-apply

setup_file() {
  # for --separate-stderr argument on 'run'
  bats_require_minimum_version 1.11.1
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

@test "sc helmfile apply is idempotent" {
  # double apply as per the QA checklist instructions
  ck8s ops helmfile sc apply
  ck8s ops helmfile sc apply

  run --separate-stderr bash -c "ck8s ops helmfile sc diff --output json | sed -n '/^\[/p' | jq -s 'reduce .[] as \$item (0; . + (\$item | length))'"
  assert_output "0"
}

@test "wc helmfile apply is idempotent" {
  # double apply as per the QA checklist instructions

  ck8s ops helmfile wc apply
  ck8s ops helmfile wc apply
  run --separate-stderr bash -c "ck8s ops helmfile wc diff --output json | sed -n '/^\[/p' | jq -s 'reduce .[] as \$item (0; . + (\$item | length))'"
  assert_output "0"
}
