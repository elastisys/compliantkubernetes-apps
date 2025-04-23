#!/usr/bin/env bash

setup_suite() {
  export CK8S_AUTO_APPROVE="true"
  export BATS_NO_PARALLELIZE_WITHIN_FILE="true"

  load "../../bats.lib.bash"

  auto_setup wc app=kyverno
}

teardown_suite() {
  load "../../bats.lib.bash"

  auto_teardown wc
}
