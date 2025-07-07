#!/usr/bin/env bats

# bats file_tags=static,general,bin:update_ips

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init openstack capi dev
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

update_ips.mock_minimal_with_subnet() {
  update_ips.mock_minimal

  mock_set_output "${mock_kubectl}" "" 1                                     # check if cluster with name <environment>-sc exists
  mock_set_output "${mock_kubectl}" "" 2                                     # check if cluster with name <environment>-<cluster> exists
  mock_set_output "${mock_kubectl}" "[1]" 3                                  # check number of subnets in cluster
  mock_set_output "${mock_kubectl}" "10.0.0.0/24" 4                          # .networkPolicies.global.scApiserver.ips cluster subnet
  mock_set_output "${mock_kubectl}" "127.0.1.2 127.0.2.2 127.0.3.2" 5        # .networkPolicies.global.scApiserver.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.21 127.0.2.21 127.0.3.21" 6     # .networkPolicies.global.scApiserver.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.3 127.0.2.3 127.0.3.3" 7        # .networkPolicies.global.scApiserver.ips calico wireguard
  mock_set_output "${mock_kubectl}" "" 8                                     # .networkPolicies.global.scApiserver.ips cilium crds
  mock_set_output "${mock_kubectl}" "" 9                                     # .networkPolicies.global.scApiserver.ips cilium internal
  mock_set_output "${mock_kubectl}" "" 10                                    # check if cluster with name <environment>-sc exists
  mock_set_output "${mock_kubectl}" "" 11                                    # check if cluster with name <environment>-<cluster> exists
  mock_set_output "${mock_kubectl}" "[1]" 12                                 # check number of subnets in cluster
  mock_set_output "${mock_kubectl}" "10.0.0.0/24" 13                         # .networkPolicies.global.scNodes.ips cluster subnet
  mock_set_output "${mock_kubectl}" "127.0.1.8 127.0.2.8 127.0.3.8" 14       # .networkPolicies.global.scNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.81 127.0.2.81 127.0.3.81" 15    # .networkPolicies.global.scNodes.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.9 127.0.2.9 127.0.3.9" 16       # .networkPolicies.global.scNodes.ips calico wireguard
  mock_set_output "${mock_kubectl}" "" 17                                    # .networkPolicies.global.scNodes.ips cilium crds
  mock_set_output "${mock_kubectl}" "" 18                                    # .networkPolicies.global.scNodes.ips cilium internal
  mock_set_output "${mock_kubectl}" "" 19                                    # check if cluster with name <environment>-<cluster> exists
  mock_set_output "${mock_kubectl}" "[1]" 20                                 # check number of subnets in cluster
  mock_set_output "${mock_kubectl}" "10.0.1.0/24" 21                         # .networkPolicies.global.wcApiserver.ips cluster subnet
  mock_set_output "${mock_kubectl}" "127.0.1.5 127.0.2.5 127.0.3.5" 22       # .networkPolicies.global.wcApiserver.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.51 127.0.2.51 127.0.3.51" 23    # .networkPolicies.global.wcApiserver.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.6 127.0.2.6 127.0.3.6" 24       # .networkPolicies.global.wcApiserver.ips calico wireguard
  mock_set_output "${mock_kubectl}" "" 25                                    # .networkPolicies.global.wcApiserver.ips cilium crds
  mock_set_output "${mock_kubectl}" "" 26                                    # .networkPolicies.global.wcApiserver.ips cilium internal
  mock_set_output "${mock_kubectl}" "" 27                                    # check if cluster with name <environment>-<cluster> exists
  mock_set_output "${mock_kubectl}" "[1]" 28                                 # check number of subnets in cluster
  mock_set_output "${mock_kubectl}" "10.0.1.0/24" 29                         # .networkPolicies.global.wcNodes.ips cluster subnet
  mock_set_output "${mock_kubectl}" "127.0.1.11 127.0.2.11 127.0.3.11" 30    # .networkPolicies.global.wcNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.111 127.0.2.111 127.0.3.111" 31 # .networkPolicies.global.wcNodes.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.12 127.0.2.12 127.0.3.12" 32    # .networkPolicies.global.wcNodes.ips calico wireguard
  mock_set_output "${mock_kubectl}" "" 33                                    # .networkPolicies.global.wcNodes.ips cilium crds
  mock_set_output "${mock_kubectl}" "" 34                                    # .networkPolicies.global.wcNodes.ips cilium internal
}

@test "ck8s update-ips can allow subnet" {
  update_ips.mock_minimal_with_subnet
  update_ips.populate_minimal

  run ck8s update-ips both apply

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[10.0.0.0/24, 127.0.1.2/32, 127.0.1.3/32, 127.0.1.21/32, 127.0.2.2/32, 127.0.2.3/32, 127.0.2.21/32, 127.0.3.2/32, 127.0.3.3/32, 127.0.3.21/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.scNodes.ips | . style="flow"')" "[10.0.0.0/24, 127.0.1.8/32, 127.0.1.9/32, 127.0.1.81/32, 127.0.2.8/32, 127.0.2.9/32, 127.0.2.81/32, 127.0.3.8/32, 127.0.3.9/32, 127.0.3.81/32]"
  assert_equal "$(yq.dig wc '.networkPolicies.global.wcApiserver.ips | . style="flow"')" "[10.0.1.0/24, 127.0.1.5/32, 127.0.1.6/32, 127.0.1.51/32, 127.0.2.5/32, 127.0.2.6/32, 127.0.2.51/32, 127.0.3.5/32, 127.0.3.6/32, 127.0.3.51/32]"
  assert_equal "$(yq.dig wc '.networkPolicies.global.wcNodes.ips | . style="flow"')" "[10.0.1.0/24, 127.0.1.11/32, 127.0.1.12/32, 127.0.1.111/32, 127.0.2.11/32, 127.0.2.12/32, 127.0.2.111/32, 127.0.3.11/32, 127.0.3.12/32, 127.0.3.111/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 34
}

@test "ck8s update-ips swallows existing internal ips into cluster subnet" {
  update_ips.mock_minimal_with_subnet
  update_ips.populate_minimal

  yq.set sc .networkPolicies.global.scNodes.ips '["10.0.0.1/32", "10.0.0.2/32", "10.0.0.3/32"]'
  yq.set wc .networkPolicies.global.wcNodes.ips '["10.0.1.1/32", "10.0.1.2/32", "10.0.1.3/32"]'

  run ck8s update-ips both apply

  assert_equal "$(yq.dig sc '.networkPolicies.global.scNodes.ips | . style="flow"')" "[10.0.0.0/24, 127.0.1.8/32, 127.0.1.9/32, 127.0.1.81/32, 127.0.2.8/32, 127.0.2.9/32, 127.0.2.81/32, 127.0.3.8/32, 127.0.3.9/32, 127.0.3.81/32]"
  assert_equal "$(yq.dig wc '.networkPolicies.global.wcNodes.ips | . style="flow"')" "[10.0.1.0/24, 127.0.1.11/32, 127.0.1.12/32, 127.0.1.111/32, 127.0.2.11/32, 127.0.2.12/32, 127.0.2.111/32, 127.0.3.11/32, 127.0.3.12/32, 127.0.3.111/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 34
}

@test "ck8s update-ips falls back on individual node IPs if CAPI cluster is not found" {
  update_ips.mock_minimal_with_subnet
  update_ips.populate_minimal

  mock_set_status "${mock_kubectl}" 1 27
  mock_set_output "${mock_kubectl}" "10.0.1.2 10.0.1.3 10.0.1.4" 28          # .networkPolicies.global.wcNodes.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.11 127.0.2.11 127.0.3.11" 29    # .networkPolicies.global.wcNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.111 127.0.2.111 127.0.3.111" 30 # .networkPolicies.global.wcNodes.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.12 127.0.2.12 127.0.3.12" 31    # .networkPolicies.global.wcNodes.ips calico wireguard

  run ck8s update-ips both apply

  assert_equal "$(yq.dig sc '.networkPolicies.global.scNodes.ips | . style="flow"')" "[10.0.0.0/24, 127.0.1.8/32, 127.0.1.9/32, 127.0.1.81/32, 127.0.2.8/32, 127.0.2.9/32, 127.0.2.81/32, 127.0.3.8/32, 127.0.3.9/32, 127.0.3.81/32]"
  assert_equal "$(yq.dig wc '.networkPolicies.global.wcNodes.ips | . style="flow"')" "[10.0.1.2/32, 10.0.1.3/32, 10.0.1.4/32, 127.0.1.11/32, 127.0.1.12/32, 127.0.1.111/32, 127.0.2.11/32, 127.0.2.12/32, 127.0.2.111/32, 127.0.3.11/32, 127.0.3.12/32, 127.0.3.111/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 33
}
