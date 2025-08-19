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

_apply_normalise() {
  ck8s update-ips both dry-run 2>&1 | sed "s#${CK8S_CONFIG_PATH}#/tmp/ck8s-apps-config#g"
}

@test "ck8s update-ips requires CK8S_CONFIG_PATH" {
  CK8S_CONFIG_PATH="" run ck8s update-ips both apply
  assert_failure
  assert_output --partial "Missing CK8S_CONFIG_PATH"

  update_ips.assert_mocks_none
}

@test "ck8s update-ip upcloud private nodes ingress IPs" {
  update_ips.mock_minimal

  run yq.set common .networkPolicies.global.scIngress.ips '["172.16.2.1/32"]'
  run yq.set common .networkPolicies.global.wcIngress.ips '["172.16.2.2/32"]'

  mock_set_output "${mock_dig}" "172.16.2.1" 2
  mock_set_output "${mock_dig}" "172.16.2.2" 3

  run ck8s update-ips both apply

  sc_private_address=$(jq -r '.resources[].instances[].attributes.nodes | select( . != null) | .[].networks[].ip_addresses[] | select( .listen == false) | .address' "${BATS_TEST_DIRNAME}"/resources/sc-config/terraform.tfstate)
  wc_private_address=$(jq -r '.resources[].instances[].attributes.nodes | select( . != null) | .[].networks[].ip_addresses[] | select( .listen == false) | .address' "${BATS_TEST_DIRNAME}"/resources/wc-config/terraform.tfstate)

  assert_equal "$(yq.dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[$sc_private_address/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[$wc_private_address/32]"

}
