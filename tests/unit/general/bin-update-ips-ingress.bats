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

@test "ck8s update-ips sc apply --enable ingress" {
  mock_set_output "${mock_dig}" "192.0.2.1" 1
  mock_set_output "${mock_dig}" "192.0.2.2" 2

  run ck8s update-ips sc apply --enable ingress

  assert_equal "$(yq.dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[192.0.2.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[192.0.2.2/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips wc apply --enable ingress" {
  mock_set_output "${mock_dig}" "192.0.2.1" 1
  mock_set_output "${mock_dig}" "192.0.2.2" 2

  run ck8s update-ips wc apply --enable ingress

  assert_equal "$(yq.dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[192.0.2.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[192.0.2.2/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips both apply --enable ingress" {
  mock_set_output "${mock_dig}" "192.0.2.1" 1
  mock_set_output "${mock_dig}" "192.0.2.2" 2

  run ck8s update-ips both apply --enable ingress

  assert_equal "$(yq.dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[192.0.2.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[192.0.2.2/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips both apply --enable ingress blocks all without domain records" {
  run ck8s update-ips both apply --enable ingress

  assert_equal "$(yq.dig wc '.networkPolicies.global.scIngress.ips | . style="flow"')" "[0.0.0.0/32]"
  assert_equal "$(yq.dig wc '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[0.0.0.0/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.scIngress.ips | . style="flow"')" "[0.0.0.0/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[0.0.0.0/32]"
}
