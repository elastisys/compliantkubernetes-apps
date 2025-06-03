#!/usr/bin/env bats

# bats file_tags=static,general,bin:common

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init baremetal kubespray air-gapped --skip-issuers --skip-network-policies
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_mock

  mock_kubectl="$(mock_create)"
  export mock_kubectl
  kubectl() {
    # shellcheck disable=SC2317
    "${mock_kubectl}" "${@}"
  }
  export -f kubectl
}

@test "check_node_label success" {
  # shellcheck source=bin/common.bash
  source ../bin/common.bash

  mock_set_output "${mock_kubectl}" -n ""

  run check_node_label sc elastisys.io/node-group
  assert_output ""
}

@test "check_node_label failure" {
  # shellcheck source=bin/common.bash
  source ../bin/common.bash

  mock_set_output "${mock_kubectl}" "node/foo"

  run check_node_label sc elastisys.io/node-group
  assert_output --partial "Found nodes that are missing the label 'elastisys.io/node-group'"
  assert_output --partial "foo"
}
