#!/usr/bin/env bats

# bats file_tags=static,general,bin:update_ips

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init baremetal kubespray dev --skip-object-storage --skip-network-policies

  yq.set common .objectStorage.type '"s3"'
  yq.set common .objectStorage.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'
}

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "update-ips.bash"
  load_common "yq.bash"
  load_assert
  load_mock

  env.private

  update_ips.setup_mocks

  export mock_curl
  export mock_dig
  export mock_kubectl
}

teardown() {
  env.teardown
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "ck8s update-ips requires CK8S_CONFIG_PATH" {
  CK8S_CONFIG_PATH="" run ck8s update-ips both apply
  assert_failure
  assert_output --partial "Missing CK8S_CONFIG_PATH"

  update_ips.assert_mocks_none
}

@test "ck8s update-ips requires .global.baseDomain" {
  yq.set common .global.baseDomain '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".global.baseDomain is not configured"

  update_ips.assert_mocks_none
}

@test "ck8s update-ips requires .global.opsDomain" {
  yq.set common .global.opsDomain '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".global.opsDomain is not configured"

  update_ips.assert_mocks_none
}

@test "ck8s update-ips both operations" {
  run ck8s update-ips both operations
  assert_success
  assert_output "rclone ingress objectstorage apiserver nodes swift"
}

@test "ck8s update-ips both operations --enable ingress" {
  run ck8s update-ips both operations --enable ingress
  assert_success
  assert_output "ingress"
}

@test "ck8s update-ips both operations --disable ingress" {
  run ck8s update-ips both operations --disable ingress
  assert_success
  assert_output "rclone objectstorage apiserver nodes swift"
}

@test "ck8s update-ips both operations --enable ingress --enable apiserver" {
  run ck8s update-ips both operations --enable ingress --enable apiserver
  assert_success
  assert_output "ingress apiserver"
}

@test "ck8s update-ips both operations --disable ingress --disable apiserver" {
  run ck8s update-ips both operations --disable ingress --disable apiserver
  assert_success
  assert_output "rclone objectstorage nodes swift"
}

@test "ck8s update-ips both operations --enable ingress --enable apiserver --disable apiserver" {
  run ck8s update-ips both operations --enable ingress --enable apiserver --disable apiserver
  assert_success
  assert_output "ingress"
}
