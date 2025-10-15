#!/usr/bin/env bats

# bats file_tags=static,general,bin:update_ips

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init openstack capi dev --skip-object-storage --skip-network-policies
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

_mock_sc() {
  mock_set_output "${mock_kubectl}" "" 1             # check if cluster with name <environment>-sc exists
  mock_set_output "${mock_kubectl}" "" 2             # check if cluster with name <environment>-<cluster> exists
  mock_set_output "${mock_kubectl}" "[1]" 3          # check number of subnets in cluster
  mock_set_output "${mock_kubectl}" "192.0.2.0/24" 4 # cluster subnet
  mock_set_output "${mock_kubectl}" "203.0.113.1" 5  # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.2" 6  # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.3" 7  # calico wireguard
  mock_set_output "${mock_kubectl}" "" 8             # cilium internal
}

_mock_wc() {
  mock_set_output "${mock_kubectl}" "" 1             # check if cluster with name <environment>-<cluster> exists
  mock_set_output "${mock_kubectl}" "[1]" 2          # check number of subnets in cluster
  mock_set_output "${mock_kubectl}" "192.0.2.0/24" 3 # cluster subnet
  mock_set_output "${mock_kubectl}" "203.0.113.1" 4  # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.2" 5  # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.3" 6  # calico wireguard
  mock_set_output "${mock_kubectl}" "" 7             # cilium internal
}

_assert_sc() {
  assert_equal "$(yq.dig sc "${1}"' | . style="flow"')" "[192.0.2.0/24, 203.0.113.1/32, 203.0.113.2/32, 203.0.113.3/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 8
}

_assert_wc() {
  assert_equal "$(yq.dig wc "${1}"' | . style="flow"')" "[192.0.2.0/24, 203.0.113.1/32, 203.0.113.2/32, 203.0.113.3/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 7
}

@test "ck8s update-ips sc apply --enable apiserver can allow subnet" {
  _mock_sc
  run ck8s update-ips sc apply --enable apiserver
  _assert_sc .networkPolicies.global.scApiserver.ips
}

@test "ck8s update-ips sc apply --enable nodes can allow subnet" {
  _mock_sc
  run ck8s update-ips sc apply --enable nodes
  _assert_sc .networkPolicies.global.scNodes.ips
}

@test "ck8s update-ips wc apply --enable apiserver can allow subnet" {
  _mock_wc
  run ck8s update-ips wc apply --enable apiserver
  _assert_wc .networkPolicies.global.wcApiserver.ips
}

@test "ck8s update-ips wc apply --enable nodes can allow subnet" {
  _mock_wc
  run ck8s update-ips wc apply --enable nodes
  _assert_wc .networkPolicies.global.wcNodes.ips
}

@test "ck8s update-ips sc apply --enable apiserver swallows existing internal ips into cluster subnet" {
  yq.set sc .networkPolicies.global.scApiserver.ips '["192.0.2.1/32", "192.0.2.2/32", "192.0.2.3/32"]'
  _mock_sc
  run ck8s update-ips sc apply --enable apiserver
  _assert_sc .networkPolicies.global.scApiserver.ips
}

@test "ck8s update-ips sc apply --enable nodes swallows existing internal ips into cluster subnet" {
  yq.set sc .networkPolicies.global.scNodes.ips '["192.0.2.1/32", "192.0.2.2/32", "192.0.2.3/32"]'
  _mock_sc
  run ck8s update-ips sc apply --enable nodes
  _assert_sc .networkPolicies.global.scNodes.ips
}

@test "ck8s update-ips wc apply --enable apiserver swallows existing internal ips into cluster subnet" {
  yq.set wc .networkPolicies.global.wcApiserver.ips '["192.0.2.1/32", "192.0.2.2/32", "192.0.2.3/32"]'
  _mock_wc
  run ck8s update-ips wc apply --enable apiserver
  _assert_wc .networkPolicies.global.wcApiserver.ips
}

@test "ck8s update-ips wc apply --enable nodes swallows existing internal ips into cluster subnet" {
  yq.set wc .networkPolicies.global.wcNodes.ips '["192.0.2.1/32", "192.0.2.2/32", "192.0.2.3/32"]'
  _mock_wc
  run ck8s update-ips wc apply --enable nodes
  _assert_wc .networkPolicies.global.wcNodes.ips
}

_mock_fallback_sc() {
  mock_set_status "${mock_kubectl}" 1 1                               # check if cluster with name <environment>-sc exists
  mock_set_status "${mock_kubectl}" 1 2                               # check if cluster with name <environment>-<cluster> exists
  mock_set_output "${mock_kubectl}" "192.0.2.1 192.0.2.2 192.0.2.3" 3 # node internal
  mock_set_output "${mock_kubectl}" "203.0.113.1" 4                   # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.2" 5                   # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.3" 6                   # calico wireguard
  mock_set_output "${mock_kubectl}" "" 7                              # cilium internal
}

_mock_fallback_wc() {
  mock_set_status "${mock_kubectl}" 1 1                               # check if cluster with name <environment>-<cluster> exists
  mock_set_output "${mock_kubectl}" "192.0.2.1 192.0.2.2 192.0.2.3" 2 # node internal
  mock_set_output "${mock_kubectl}" "203.0.113.1" 3                   # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.2" 4                   # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.3" 5                   # calico wireguard
  mock_set_output "${mock_kubectl}" "" 6                              # cilium internal
}

_assert_fallback_sc() {
  assert_equal "$(yq.dig sc "${1}"' | . style="flow"')" "[192.0.2.1/32, 192.0.2.2/32, 192.0.2.3/32, 203.0.113.1/32, 203.0.113.2/32, 203.0.113.3/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 7
}

_assert_fallback_wc() {
  assert_equal "$(yq.dig wc "${1}"' | . style="flow"')" "[192.0.2.1/32, 192.0.2.2/32, 192.0.2.3/32, 203.0.113.1/32, 203.0.113.2/32, 203.0.113.3/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 6
}

@test "ck8s update-ips sc apply --enable apiserver falls back on individual node IPs if CAPI cluster is not found" {
  _mock_fallback_sc
  run ck8s update-ips sc apply --enable apiserver
  _assert_fallback_sc .networkPolicies.global.scApiserver.ips
}

@test "ck8s update-ips sc apply --enable nodes falls back on individual node IPs if CAPI cluster is not found" {
  _mock_fallback_sc
  run ck8s update-ips sc apply --enable nodes
  _assert_fallback_sc .networkPolicies.global.scNodes.ips
}

@test "ck8s update-ips wc apply --enable apiserver falls back on individual node IPs if CAPI cluster is not found" {
  _mock_fallback_wc
  run ck8s update-ips wc apply --enable apiserver
  _assert_fallback_wc .networkPolicies.global.wcApiserver.ips
}

@test "ck8s update-ips wc apply --enable nodes falls back on individual node IPs if CAPI cluster is not found" {
  _mock_fallback_wc
  run ck8s update-ips wc apply --enable nodes
  _assert_fallback_wc .networkPolicies.global.wcNodes.ips
}
