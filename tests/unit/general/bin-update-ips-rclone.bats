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

  yq.set sc .objectStorage.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq.set sc .objectStorage.swift.region '"swift-region"'

  sops --set '["objectStorage"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  yq.set sc .objectStorage.sync.enabled 'true'

  yq.set sc .objectStorage.sync.destinationType '"none"'
  yq.set sc .objectStorage.sync.syncDefaultBuckets 'false'

  yq.set sc .networkPolicies.rclone.enabled 'true'
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

# ---- setup -----------------------------------------------------------------------------------------------------------

_setup_s3() {
  update_ips.mock_rclone_s3

  yq.set sc "${1}" '"s3"'
  yq.set sc .objectStorage.sync.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'
}

_setup_s3_and_swift() {
  update_ips.mock_rclone_s3_and_swift

  yq.set sc "${1}" '"s3"'
  yq.set sc .objectStorage.sync.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'

  yq.set sc .objectStorage.sync.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq.set sc .objectStorage.sync.swift.region '"swift-region"'
  yq.set sc .objectStorage.sync.swift.domainName '"swift-domain"'
  yq.set sc .objectStorage.sync.swift.projectDomainName '"swift-project-domain"'
  yq.set sc .objectStorage.sync.swift.projectName '"swift-project"'

  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"
}

_setup_swift() {
  update_ips.mock_rclone_swift

  yq.set sc "${1}" '"swift"'
  yq.set sc .objectStorage.sync.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq.set sc .objectStorage.sync.swift.region '"swift-region"'
  yq.set sc .objectStorage.sync.swift.domainName '"swift-domain"'
  yq.set sc .objectStorage.sync.swift.projectDomainName '"swift-project-domain"'
  yq.set sc .objectStorage.sync.swift.projectName '"swift-project"'

  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"
}

_setup_swift_and_s3() {
  update_ips.mock_rclone_s3_and_swift

  yq.set sc "${1}" '"swift"'
  yq.set sc .objectStorage.sync.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq.set sc .objectStorage.sync.swift.region '"swift-region"'
  yq.set sc .objectStorage.sync.swift.domainName '"swift-domain"'
  yq.set sc .objectStorage.sync.swift.projectDomainName '"swift-project-domain"'
  yq.set sc .objectStorage.sync.swift.projectName '"swift-project"'

  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  yq.set sc .objectStorage.sync.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'
}

# --- s3 only ----------------------------------------------------------------------------------------------------------

_test_rclone_sync_s3_requires_s3_endpoint() {
  yq.set sc "${1}" '"s3"'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.s3.regionEndpoint is not configured"

  update_ips.assert_none
}

@test "ck8s update-ips requires s3 endpoint for rclone sync s3 - buckets destination type" {
  _test_rclone_sync_s3_requires_s3_endpoint '.objectStorage.sync.buckets.[0].destinationType'
}

@test "ck8s update-ips requires s3 endpoint for rclone sync s3 - destination type" {
  _test_rclone_sync_s3_requires_s3_endpoint '.objectStorage.sync.destinationType'
}

_test_apply_rclone_sync_s3() {
  _setup_s3 "${1}"

  run ck8s update-ips both apply

  update_ips.assert_rclone_s3
}

@test "ck8s update-ips sets s3 for rclone sync - buckets destination type" {
  _test_apply_rclone_sync_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "ck8s update-ips sets s3 for rclone sync - destination type" {
  _test_apply_rclone_sync_s3 '.objectStorage.sync.destinationType'
}

# --- s3 remove swift --------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_s3_remove_swift() {
  _setup_s3 "${1}"

  yq.set sc .networkPolicies.rclone.sync.objectStorageSwift.ips '["127.0.0.5/32"]'
  yq.set sc .networkPolicies.rclone.sync.objectStorageSwift.ports '[5678]'

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorageSwift' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  update_ips.assert_rclone_s3
}

@test "ck8s update-ips sets s3 and removes swift for rclone sync - buckets destination type" {
  _test_apply_rclone_sync_s3_remove_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "ck8s update-ips sets s3 and removes swift for rclone sync - destination type" {
  _test_apply_rclone_sync_s3_remove_swift '.objectStorage.sync.destinationType'
}

# --- s3 add swift -----------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_s3_add_swift() {
  _setup_s3_and_swift "${1}"

  run ck8s update-ips both apply

  update_ips.assert_rclone_s3_and_swift
}

@test "ck8s update-ips sets s3 and adds swift for rclone sync - buckets destination type" {
  _test_apply_rclone_sync_s3_add_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "ck8s update-ips sets s3 and adds swift for rclone sync - destination type" {
  _test_apply_rclone_sync_s3_add_swift '.objectStorage.sync.destinationType'
}

# --- swift -----------------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_swift_requires_swift_endpoint() {
  _setup_swift "${1}"

  yq.set sc .objectStorage.sync.swift.authUrl '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.swift.authUrl is not configured"

  update_ips.assert_none
}

@test "ck8s update-ips requires swift endpoint for rclone sync - buckets destination type" {
  _test_apply_rclone_sync_swift_requires_swift_endpoint '.objectStorage.sync.buckets.[0].destinationType'
}

@test "ck8s update-ips requires swift endpoint for rclone sync - destination type" {
  _test_apply_rclone_sync_swift_requires_swift_endpoint '.objectStorage.sync.destinationType'
}

@test "ck8s update-ips requires swift endpoint for rclone sync - harbor" {
  yq.set sc .objectStorage.sync.syncDefaultBuckets "true"

  _test_apply_rclone_sync_swift_requires_swift_endpoint '.harbor.persistence.type'
}

@test "ck8s update-ips requires swift endpoint for rclone sync - thanos" {
  yq.set sc .objectStorage.sync.syncDefaultBuckets "true"

  _test_apply_rclone_sync_swift_requires_swift_endpoint '.thanos.objectStorage.type'
}

_test_apply_rclone_sync_swift() {
  _setup_swift "${1}"

  run ck8s update-ips both apply

  update_ips.assert_rclone_swift
}

@test "ck8s update-ips sets swift for rclone sync - buckets destination type" {
  _test_apply_rclone_sync_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "ck8s update-ips sets swift for rclone sync - destination type" {
  _test_apply_rclone_sync_swift '.objectStorage.sync.destinationType'
}

# --- swift remove s3 --------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_swift_remove_s3() {
  _setup_swift "${1}"

  yq.set sc .networkPolicies.rclone.sync.objectStorage.ips '["127.0.0.5/32"]'
  yq.set sc .networkPolicies.rclone.sync.objectStorage.ports '[5678]'

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorage' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  update_ips.assert_rclone_swift
}

@test "ck8s update-ips sets swift and remove s3 for rclone sync - buckets destination type" {
  _test_apply_rclone_sync_swift_remove_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "ck8s update-ips sets swift and remove s3 for rclone sync - destination type" {
  _test_apply_rclone_sync_swift_remove_s3 '.objectStorage.sync.destinationType'
}


# --- swift add s3 -----------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_swift_add_s3() {
  _setup_swift_and_s3 "${1}"

  run ck8s update-ips both apply

  update_ips.assert_rclone_s3_and_swift
}

@test "ck8s update-ips sets swift and adds s3 for rclone sync - buckets destination type" {
  _test_apply_rclone_sync_swift_add_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "ck8s update-ips sets swift and adds s3 for rclone sync - destination type" {
  _test_apply_rclone_sync_swift_add_s3 '.objectStorage.sync.destinationType'
}

# --- s3 and swift -----------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint() {
  yq.set sc .objectStorage.sync.s3.regionEndpoint '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.s3.regionEndpoint is not configured"

  update_ips.assert_none
}

@test "ck8s update-ips requires s3 endpoint for rclone sync - s3 destination type and swift bucket destination type" {
  _setup_s3_and_swift '.objectStorage.sync.destinationType'
  yq.set sc .objectStorage.sync.buckets.[0].destinationType '"s3"'
  yq.set sc .objectStorage.sync.buckets.[1].destinationType '"swift"'

  _test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint
}

@test "ck8s update-ips requires s3 endpoint for rclone sync - swift destination type and s3 bucket destination type" {
  _setup_swift_and_s3 '.objectStorage.sync.destinationType'
  yq.set sc .objectStorage.sync.buckets.[0].destinationType '"swift"'
  yq.set sc .objectStorage.sync.buckets.[1].destinationType '"s3"'

  _test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint
}

_test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint() {
  yq.set sc .objectStorage.sync.swift.authUrl '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.swift.authUrl is not configured"

  update_ips.assert_none
}

@test "ck8s update-ips requires swift endpoint for rclone sync - s3 destination type and swift bucket destination type" {
  _setup_s3_and_swift '.objectStorage.sync.destinationType'
  yq.set sc .objectStorage.sync.buckets.[0].destinationType '"s3"'
  yq.set sc .objectStorage.sync.buckets.[1].destinationType '"swift"'

  _test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint
}

@test "ck8s update-ips requires swift endpoint for rclone sync - swift destination type and s3 bucket destination type" {
  _setup_swift_and_s3 '.objectStorage.sync.destinationType'
  yq.set sc .objectStorage.sync.buckets.[0].destinationType '"swift"'
  yq.set sc .objectStorage.sync.buckets.[1].destinationType '"s3"'

  _test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint
}

_test_apply_rclone_sync_s3_and_swift() {
  run ck8s update-ips both apply

  update_ips.assert_rclone_s3_and_swift
}

@test "ck8s update-ips sets s3 and swift for rclone sync - s3 destination type and swift bucket destination type" {
  _setup_s3_and_swift '.objectStorage.sync.destinationType'
  yq.set sc .objectStorage.sync.buckets.[0].destinationType '"s3"'
  yq.set sc .objectStorage.sync.buckets.[1].destinationType '"swift"'

  _test_apply_rclone_sync_s3_and_swift
}

@test "ck8s update-ips sets swift and s3 for rclone sync - swift destination type and s3 bucket destination type" {
  _setup_swift_and_s3 '.objectStorage.sync.destinationType'
  yq.set sc .objectStorage.sync.buckets.[0].destinationType '"swift"'
  yq.set sc .objectStorage.sync.buckets.[1].destinationType '"s3"'

  _test_apply_rclone_sync_s3_and_swift
}

# --- secondary --------------------------------------------------------------------------------------------------------

@test "ck8s update-ips sets secondary URL for rclone sync" {
  yq.set sc .objectStorage.sync.secondaryUrl '"https://s3.foo.dev-ck8s.com:1234"'

  update_ips.mock_minimal
  mock_set_output "${mock_dig}" "127.0.0.4" 4 # .objectStorage.sync.secondaryUrl

  run ck8s update-ips both apply

  assert_equal "$(yq.dig sc '.networkPolicies.rclone.sync.secondaryUrl.ips | . style="flow"')" "[127.0.0.4/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.rclone.sync.secondaryUrl.ports | . style="flow"')" "[1234]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 4
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "ck8s update-ips removes secondary URL for rclone sync" {
  yq.set sc .networkPolicies.rclone.sync.secondaryUrl.ips '["127.0.0.4"]'
  yq.set sc .networkPolicies.rclone.sync.secondaryUrl.ports '[1234]'

  update_ips.mock_minimal
  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.secondaryUrl' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

# --- get-swift-url ----------------------------------------------------------------------------------------------------

@test "ck8s update-ips gets swift url for rclone sync" {
  _setup_swift '.objectStorage.sync.destinationType'

  mock_set_output "${mock_dig}" ""

  run ck8s update-ips both apply

  assert_equal "$(mock_get_call_args "${mock_curl}" 1)" "$(cat "${BATS_TEST_DIRNAME}/resources/get-swift-url-username.out")"
}
