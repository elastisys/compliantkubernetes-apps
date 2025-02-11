#!/usr/bin/env bats

# bats file_tags=static,general,bin:version

setup_file() {
  load "../../bats.lib.bash"
}

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_assert
  load_file

  CK8S_CONFIG_PATH="$(mktemp --directory)"
  export CK8S_CONFIG_PATH
  export CK8S_ENVIRONMENT_NAME="unit-test"
  export CK8S_CLOUD_PROVIDER="baremetal"
  export CK8S_K8S_INSTALLER="kubespray"
  export CK8S_FLAVOR="dev"
}

@test "ck8s version config" {
  run ck8s version config
  assert_success
}
