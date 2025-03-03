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

_apply_normalise() {
  ck8s update-ips both dry-run 2>&1 | sed "s#${CK8S_CONFIG_PATH}#/tmp/ck8s-apps-config#g"
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

@test "ck8s update-ips requires .objectStorage.s3.regionEndpoint" {
  yq.set common .objectStorage.s3.regionEndpoint '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.s3.regionEndpoint is not configured"

  update_ips.assert_mocks_none
}

@test "ck8s update-ips performs minimal run" {
  update_ips.mock_minimal

  run ck8s update-ips both apply

  update_ips.assert_minimal
}

@test "ck8s update-ips blocks all without domain records" {
  run ck8s update-ips both apply

  assert_equal "$(yq.dig wc '.networkPolicies.global.scIngress.ips | . style="flow"')" "[0.0.0.0/32]"
  assert_equal "$(yq.dig wc '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[0.0.0.0/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.scIngress.ips | . style="flow"')" "[0.0.0.0/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[0.0.0.0/32]"
}

@test "ck8s update-ips performs minimal run with zero diff" {
  update_ips.mock_minimal
  update_ips.populate_minimal

  run _apply_normalise
  # assert_success # isn't passed through by _apply_normalise

  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/zero-diff.out")"
}

@test "ck8s update-ips sorts ips" {
  update_ips.mock_minimal
  update_ips.populate_minimal

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1 126.0.0.20 126.0.0.3" 1 # .networkPolicies.global.scApiserver.ips internal ip

  run ck8s update-ips both apply

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[126.0.0.3/32, 126.0.0.20/32, 127.0.1.1/32, 127.0.1.2/32, 127.0.1.3/32, 127.0.1.21/32, 127.0.2.1/32, 127.0.2.2/32, 127.0.2.3/32, 127.0.2.21/32, 127.0.3.1/32, 127.0.3.2/32, 127.0.3.3/32, 127.0.3.21/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
}

@test "ck8s update-ips skips ips in existing cidrs" {
  update_ips.mock_minimal
  update_ips.populate_minimal

  yq.set sc .networkPolicies.global.scApiserver.ips '["127.0.0.0/16", "127.1.0.0/16"]'

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1 127.1.0.0 127.1.0.1 127.2.0.1" 1 # .networkPolicies.global.scApiserver.ips internal ip

  run ck8s update-ips both apply

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[127.0.0.0/16, 127.1.0.0/16, 127.2.0.1/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
}

@test "ck8s update-ips allows s3 region endpoint to be an ip" {
  update_ips.mock_minimal

  yq.set common .objectStorage.s3.regionEndpoint '"http://192.168.1.1:8080"'

  run ck8s update-ips both apply

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[192.168.1.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[8080]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
}

@test "ck8s update-ips allows s3 region endpoint to be cluster local with kubeadm config" {
  update_ips.mock_minimal

  yq.set common .objectStorage.s3.regionEndpoint '"http://minio.minio-system.svc.cluster.local"'

  mock_set_output "${mock_kubectl}" 'data: { ClusterConfiguration: "networking: { podSubnet: 10.244.0.0/16 }" }' 1

  run ck8s update-ips both apply

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[10.244.0.0/16]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 17
}

@test "ck8s update-ips allows s3 region endpoint to be cluster local without kubeadm config" {
  update_ips.mock_minimal

  yq.set common .objectStorage.s3.regionEndpoint '"http://minio.minio-system.svc.cluster.local"'

  mock_set_output "${mock_kubectl}" "" 1

  run ck8s update-ips both apply

  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[0.0.0.0/0]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 17
}

# --- maximal ----------------------------------------------------------------------------------------------------------

_configure_maximal() {
  yq.set sc .harbor.persistence.type '"swift"'
  yq.set sc .objectStorage.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq.set sc .objectStorage.swift.region '"swift-region"'

  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .networkPolicies.rclone.enabled 'true'
  yq.set sc .objectStorage.sync.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'
  yq.set sc .objectStorage.sync.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq.set sc .objectStorage.sync.swift.region '"swift-region"'

  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  yq.set sc .objectStorage.sync.secondaryUrl '"https://s3.foo.dev-ck8s.com:1234"'
}

# bats test_tags=resources
@test "ck8s update-ips performs maximal run with full diff" {
  update_ips.mock_maximal

  _configure_maximal

  if [[ "${CK8S_TESTS_REGENERATE_RESOURCES:-}" == "true" ]]; then
    _apply_normalise >"${BATS_TEST_DIRNAME}/resources/maximal-run-full-diff.out"
    return
  fi

  run _apply_normalise
  # assert_failure # isn't passed through by _apply_normalise

  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/maximal-run-full-diff.out")"
}

@test "ck8s update-ips performs maximal run with zero diff" {
  update_ips.mock_maximal
  update_ips.populate_maximal

  _configure_maximal

  run _apply_normalise
  # assert_failure # isn't passed through by _apply_normalise

  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/zero-diff.out")"
}
