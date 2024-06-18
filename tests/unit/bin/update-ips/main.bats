#!/usr/bin/env bats

# bats file_tags=static,general,bin:update_ips

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true

  load "../../../common/lib"
  load "../../../common/lib/env"
  load "../../../common/lib/gpg"

  gpg.setup
  env.setup

  common_setup

  env.init dev baremetal kubespray --skip-object-storage --skip-network-policies

  yq_set common .objectStorage.type '"s3"'
  yq_set common .objectStorage.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'
}

teardown_file() {
  env.teardown
  gpg.teardown
}

setup() {
  load "../../../common/lib"
  load "../../../common/lib/env"
  load "../../../common/lib/update-ips"

  common_setup

  env.private

  update_ips.setup_mocks

  export mock_curl
  export mock_dig
  export mock_kubectl
}

teardown() {
  env.teardown
}

_apply_normalise() {
  ck8s update-ips both dry-run 2>&1 | sed "s#${CK8S_CONFIG_PATH}#/tmp/ck8s-apps-config#g"
}

@test "update-ips - requires CK8S_CONFIG_PATH" {
  CK8S_CONFIG_PATH="" run ck8s update-ips both apply
  assert_failure
  assert_output --partial "Missing CK8S_CONFIG_PATH"

  update_ips.assert_mocks_none
}

@test "update-ips - requires .global.baseDomain" {
  yq_set common .global.baseDomain '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".global.baseDomain is not configured"

  update_ips.assert_mocks_none
}

@test "update-ips - requires .global.opsDomain" {
  yq_set common .global.opsDomain '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".global.opsDomain is not configured"

  update_ips.assert_mocks_none
}

@test "update-ips - requires .objectStorage.s3.regionEndpoint" {
  yq_set common .objectStorage.s3.regionEndpoint '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.s3.regionEndpoint is not configured"

  update_ips.assert_mocks_none
}

@test "update-ips - minimal run" {
  update_ips.mock_minimal

  run ck8s update-ips both apply

  update_ips.assert_minimal
}

@test "update-ips - minimal run zero diff" {
  update_ips.mock_minimal
  update_ips.populate_minimal

  run _apply_normalise
  # assert_success # isn't passed through by _apply_normalise

  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/zero-diff.out")"
}

@test "update-ips - sorts ips" {
  update_ips.mock_minimal
  update_ips.populate_minimal

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1 126.0.0.20 126.0.0.3" 1 # .networkPolicies.global.scApiserver.ips internal ip

  run ck8s update-ips both apply

  assert_equal "$(yq_dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[126.0.0.3/32, 126.0.0.20/32, 127.0.1.1/32, 127.0.1.2/32, 127.0.1.3/32, 127.0.1.21/32, 127.0.2.1/32, 127.0.2.2/32, 127.0.2.3/32, 127.0.2.21/32, 127.0.3.1/32, 127.0.3.2/32, 127.0.3.3/32, 127.0.3.21/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
}

@test "update-ips - skips ips in existing cidrs" {
  update_ips.mock_minimal
  update_ips.populate_minimal

  yq_set sc .networkPolicies.global.scApiserver.ips '["127.0.0.0/16", "127.1.0.0/16"]'

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1 127.1.0.0 127.1.0.1 127.2.0.1" 1 # .networkPolicies.global.scApiserver.ips internal ip

  run ck8s update-ips both apply

  assert_equal "$(yq_dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[127.0.0.0/16, 127.1.0.0/16, 127.2.0.1/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
}

@test "update-ips - s3 region endpoint can be ip" {
  update_ips.mock_minimal

  yq_set common .objectStorage.s3.regionEndpoint '"http://192.168.1.1:8080"'

  run ck8s update-ips both apply

  assert_equal "$(yq_dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[192.168.1.1/32]"
  assert_equal "$(yq_dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[8080]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
}

@test "update-ips - s3 region endpoint can be cluster local with kubeadm config" {
  update_ips.mock_minimal

  yq_set common .objectStorage.s3.regionEndpoint '"http://minio.minio-system.svc.cluster.local"'

  mock_set_output "${mock_kubectl}" 'data: { ClusterConfiguration: "networking: { podSubnet: 10.244.0.0/16 }" }' 1

  run ck8s update-ips both apply

  assert_equal "$(yq_dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[10.244.0.0/16]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 17
}

@test "update-ips - s3 region endpoint can be cluster local without kubeadm config" {
  update_ips.mock_minimal

  yq_set common .objectStorage.s3.regionEndpoint '"http://minio.minio-system.svc.cluster.local"'

  mock_set_output "${mock_kubectl}" "" 1

  run ck8s update-ips both apply

  assert_equal "$(yq_dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[0.0.0.0/0]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 17
}

# --- maximal ----------------------------------------------------------------------------------------------------------

_configure_maximal() {
  yq_set sc .harbor.persistence.type '"swift"'
  yq_set sc .objectStorage.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq_set sc .objectStorage.swift.region '"swift-region"'

  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  yq_set sc .objectStorage.sync.enabled 'true'
  yq_set sc .networkPolicies.rclone.enabled 'true'
  yq_set sc .objectStorage.sync.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'
  yq_set sc .objectStorage.sync.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq_set sc .objectStorage.sync.swift.region '"swift-region"'

  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  yq_set sc .objectStorage.sync.secondaryUrl '"https://s3.foo.dev-ck8s.com:1234"'
}

# bats test_tags=resources
@test "update-ips - maximal run full diff" {
  update_ips.mock_maximal

  _configure_maximal

  if [[ "${CK8S_TESTS_REGENERATE_RESOURCES:-}" == "true" ]]; then
    _apply_normalise > "${BATS_TEST_DIRNAME}/resources/maximal-run-full-diff.out"
    return
  fi

  run _apply_normalise
  # assert_failure # isn't passed through by _apply_normalise

  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/maximal-run-full-diff.out")"
}

@test "update-ips - maximal run zero diff" {
  update_ips.mock_maximal
  update_ips.populate_maximal

  _configure_maximal

  run _apply_normalise
  # assert_failure # isn't passed through by _apply_normalise

  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/zero-diff.out")"
}
