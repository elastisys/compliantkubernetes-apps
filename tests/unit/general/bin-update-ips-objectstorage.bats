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

@test "ck8s update-ips sc apply --enable objectstorage" {
  mock_set_output "${mock_dig}" "192.0.2.1" 1

  run ck8s update-ips sc apply --enable objectstorage

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[192.0.2.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[1234]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 1
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips wc apply --enable objectstorage" {
  mock_set_output "${mock_dig}" "192.0.2.1" 1

  run ck8s update-ips wc apply --enable objectstorage

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[192.0.2.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[1234]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 1
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips both apply --enable objectstorage" {
  mock_set_output "${mock_dig}" "192.0.2.1" 1

  run ck8s update-ips both apply --enable objectstorage

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[192.0.2.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[1234]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 1
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips both apply --enable objectstorage --ipv6" {
  mock_set_output "${mock_dig}" "192.0.2.1" 1
  mock_set_output "${mock_dig}" "fd3e:fab4:5eda:b233::1" 2

  run ck8s update-ips both apply --enable objectstorage --ipv6

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[192.0.2.1/32, 'fd3e:fab4:5eda:b233::1/128']"
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[1234]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips allows s3 region endpoint to be an ip" {
  yq.set common .objectStorage.s3.regionEndpoint '"http://192.168.1.1:8080"'

  run ck8s update-ips both apply --enable objectstorage

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[192.168.1.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[8080]"

  update_ips.assert_mocks_none
}

@test "ck8s update-ips allows s3 region endpoint to be cluster local with kubeadm config" {
  yq.set common .objectStorage.s3.regionEndpoint '"http://minio.minio-system.svc.cluster.local"'

  mock_set_output "${mock_kubectl}" 'data: { ClusterConfiguration: "networking: { podSubnet: 10.244.0.0/16 }" }' 1

  run ck8s update-ips both apply --enable objectstorage

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[10.244.0.0/16]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 1
}

@test "ck8s update-ips allows s3 region endpoint to be cluster local without kubeadm config" {
  yq.set common .objectStorage.s3.regionEndpoint '"http://minio.minio-system.svc.cluster.local"'

  run ck8s update-ips both apply --enable objectstorage

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[0.0.0.0/0]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 1
}
