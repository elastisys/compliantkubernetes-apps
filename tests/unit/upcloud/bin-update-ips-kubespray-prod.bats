#!/usr/bin/env bats

# bats file_tags=static,upcloud,bin:update_ips

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init upcloud kubespray prod
}

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "update-ips.bash"
  load_common "yq.bash"
  load_assert
  load_mock

  env.private

  mkdir "${CK8S_CONFIG_PATH}/sc-config"
  mkdir "${CK8S_CONFIG_PATH}/wc-config"
  cp "${BATS_TEST_DIRNAME}/resources/sc-config/terraform.tfstate" "${CK8S_CONFIG_PATH}/sc-config/terraform.tfstate"
  cp "${BATS_TEST_DIRNAME}/resources/wc-config/terraform.tfstate" "${CK8S_CONFIG_PATH}/wc-config/terraform.tfstate"

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

@test "ck8s update-ip upcloud private nodes ingress IPs" {
  update_ips.mock_minimal
  update_ips.populate_minimal

  run ck8s update-ips both apply
  assert_success

  sc_private_address="$(jq -r '.resources[].instances[].attributes.nodes | select( . != null) | .[].networks[].ip_addresses[] | select( .listen == false) | .address' "${BATS_TEST_DIRNAME}/resources/sc-config/terraform.tfstate")"
  wc_private_address="$(jq -r '.resources[].instances[].attributes.nodes | select( . != null) | .[].networks[].ip_addresses[] | select( .listen == false) | .address' "${BATS_TEST_DIRNAME}/resources/wc-config/terraform.tfstate")"

  assert_equal "$(yq.dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[127.0.0.2/32, ${sc_private_address}/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[127.0.0.3/32, ${wc_private_address}/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 20

}
