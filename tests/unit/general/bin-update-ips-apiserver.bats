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

@test "ck8s update-ips sc apply --enable apiserver" {
  mock_set_output "${mock_kubectl}" "192.0.2.1 192.0.2.2 192.0.2.3" 1             # node internal
  mock_set_output "${mock_kubectl}" "198.51.100.1 198.51.100.2 198.51.100.3" 2    # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.1 203.0.113.2 203.0.113.3" 3       # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.101 203.0.113.102 203.0.113.103" 4 # calico wireguard
  mock_set_output "${mock_kubectl}" "192.0.2.10 192.0.2.11 192.0.2.12" 5          # cilium internal

  run ck8s update-ips sc apply --enable apiserver

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" \
    "[192.0.2.1/32, 192.0.2.2/32, 192.0.2.3/32, 192.0.2.10/32, 192.0.2.11/32, 192.0.2.12/32, 198.51.100.1/32, 198.51.100.2/32, 198.51.100.3/32, 203.0.113.1/32, 203.0.113.2/32, 203.0.113.3/32, 203.0.113.101/32, 203.0.113.102/32, 203.0.113.103/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 5
}

@test "ck8s update-ips wc apply --enable apiserver" {
  mock_set_output "${mock_kubectl}" "192.0.2.1 192.0.2.2 192.0.2.3" 1             # node internal
  mock_set_output "${mock_kubectl}" "198.51.100.1 198.51.100.2 198.51.100.3" 2    # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.1 203.0.113.2 203.0.113.3" 3       # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.101 203.0.113.102 203.0.113.103" 4 # calico wireguard
  mock_set_output "${mock_kubectl}" "192.0.2.10 192.0.2.11 192.0.2.12" 5          # cilium internal

  run ck8s update-ips wc apply --enable apiserver

  assert_equal "$(yq.dig wc '.networkPolicies.global.wcApiserver.ips | . style="flow"')" \
    "[192.0.2.1/32, 192.0.2.2/32, 192.0.2.3/32, 192.0.2.10/32, 192.0.2.11/32, 192.0.2.12/32, 198.51.100.1/32, 198.51.100.2/32, 198.51.100.3/32, 203.0.113.1/32, 203.0.113.2/32, 203.0.113.3/32, 203.0.113.101/32, 203.0.113.102/32, 203.0.113.103/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 5
}

@test "ck8s update-ips both apply --enable apiserver" {
  mock_set_output "${mock_kubectl}" "192.0.2.1" 1     # node internal
  mock_set_output "${mock_kubectl}" "198.51.100.1" 2  # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.1" 3   # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.101" 4 # calico wireguard
  mock_set_output "${mock_kubectl}" "192.0.2.10" 5    # cilium internal

  mock_set_output "${mock_kubectl}" "192.0.2.2" 6     # node internal
  mock_set_output "${mock_kubectl}" "198.51.100.2" 7  # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.2" 8   # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.102" 9 # calico wireguard
  mock_set_output "${mock_kubectl}" "192.0.2.11" 10   # cilium internal

  run ck8s update-ips both apply --enable apiserver

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" \
    "[192.0.2.1/32, 192.0.2.10/32, 198.51.100.1/32, 203.0.113.1/32, 203.0.113.101/32]"

  assert_equal "$(yq.dig wc '.networkPolicies.global.wcApiserver.ips | . style="flow"')" \
    "[192.0.2.2/32, 192.0.2.11/32, 198.51.100.2/32, 203.0.113.2/32, 203.0.113.102/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 10
}

@test "ck8s update-ips both apply --enable apiserver --ipv6" {
  mock_set_output "${mock_kubectl}" "192.0.2.1" 1              # node internal
  mock_set_output "${mock_kubectl}" "198.51.100.1" 2           # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.1" 3            # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.101" 4          # calico wireguard
  mock_set_output "${mock_kubectl}" "fd3e:fab4:5eda:b233::1" 5 # calico vxlan ipv6
  mock_set_output "${mock_kubectl}" "fd3e:fab4:5eda:b233::2" 6 # calico ipip ipv6
  mock_set_output "${mock_kubectl}" "192.0.2.10" 7             # cilium internal

  mock_set_output "${mock_kubectl}" "192.0.2.2" 8               # node internal
  mock_set_output "${mock_kubectl}" "198.51.100.2" 9            # calico ipip
  mock_set_output "${mock_kubectl}" "203.0.113.2" 10            # calico vxlan
  mock_set_output "${mock_kubectl}" "203.0.113.102" 11          # calico wireguard
  mock_set_output "${mock_kubectl}" "fd3e:fab4:5eda:b233::3" 12 # calico vxlan ipv6
  mock_set_output "${mock_kubectl}" "fd3e:fab4:5eda:b233::4" 13 # calico ipip ipv6
  mock_set_output "${mock_kubectl}" "192.0.2.11" 14             # cilium internal

  run ck8s update-ips both apply --enable apiserver --ipv6

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" \
    "[192.0.2.1/32, 192.0.2.10/32, 198.51.100.1/32, 203.0.113.1/32, 203.0.113.101/32, 'fd3e:fab4:5eda:b233::1/128', 'fd3e:fab4:5eda:b233::2/128']"

  assert_equal "$(yq.dig wc '.networkPolicies.global.wcApiserver.ips | . style="flow"')" \
    "[192.0.2.2/32, 192.0.2.11/32, 198.51.100.2/32, 203.0.113.2/32, 203.0.113.102/32, 'fd3e:fab4:5eda:b233::3/128', 'fd3e:fab4:5eda:b233::4/128']"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 14
}

@test "ck8s update-ips sc apply --enable apiserver sorts ips" {
  yq.set sc .networkPolicies.global.scApiserver.ips '["203.0.113.1/32", "192.0.2.1/32", "192.0.2.10/32", "192.0.2.100/32", "192.0.2.2/32"]'

  mock_set_output "${mock_kubectl}" "192.0.2.1" 1   # node internal
  mock_set_output "${mock_kubectl}" "192.0.2.2" 2   # calico ipip
  mock_set_output "${mock_kubectl}" "192.0.2.10" 3  # calico vxlan
  mock_set_output "${mock_kubectl}" "192.0.2.100" 4 # calico wireguard
  mock_set_output "${mock_kubectl}" "203.0.113.1" 5 # cilium internal

  run ck8s update-ips sc apply --enable apiserver

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[192.0.2.1/32, 192.0.2.2/32, 192.0.2.10/32, 192.0.2.100/32, 203.0.113.1/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 5
}

@test "ck8s update-ips sc apply --enable apiserver skips ips in existing cidrs" {
  yq.set sc .networkPolicies.global.scApiserver.ips '["192.0.2.0/24", "198.51.100.0/24"]'

  mock_set_output "${mock_kubectl}" "192.0.2.1 192.0.2.2 192.0.2.3" 1          # node internal
  mock_set_output "${mock_kubectl}" "198.51.100.1 198.51.100.2 198.51.100.3" 2 # calico ipip
  mock_set_output "${mock_kubectl}" "192.0.2.4 192.0.2.5 192.0.2.6" 3          # calico vxlan
  mock_set_output "${mock_kubectl}" "198.51.100.4 198.51.100.5 198.51.100.6" 4 # calico wireguard
  mock_set_output "${mock_kubectl}" "203.0.113.1" 5                            # cilium internal

  run ck8s update-ips sc apply --enable apiserver

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[192.0.2.0/24, 198.51.100.0/24, 203.0.113.1/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 5
}
