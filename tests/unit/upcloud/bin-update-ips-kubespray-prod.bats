#!/usr/bin/env bats

# bats file_tags=static,upcloud,bin:update_ips

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init upcloud kubespray prod --skip-object-storage --skip-network-policies

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

@test "ck8s update-ips both apply --enable ingress on upcloud gets private nodes ingress IPs from Terraform state file" {
  mock_set_output "${mock_dig}" "192.0.2.1" 1
  mock_set_output "${mock_dig}" "192.0.2.2" 2

  run ck8s update-ips both apply --enable ingress
  assert_success

  assert_equal "$(yq.dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[192.0.2.1/32, 203.0.113.2/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[192.0.2.2/32, 203.0.113.4/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0

}
