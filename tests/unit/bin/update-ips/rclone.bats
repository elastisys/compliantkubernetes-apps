#!/usr/bin/env bats

# bats file_tags=static,general,bin:update_ips

setup_file() {
  load "../../../common/lib"
  load "../../../common/lib/env"
  load "../../../common/lib/gpg"

  env.setup
  gpg.setup

  common_setup

  env.init dev baremetal --skip-object-storage --skip-network-policies

  yq_set common .objectStorage.type '"s3"'
  yq_set common .objectStorage.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'

  yq_set sc .objectStorage.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq_set sc .objectStorage.swift.region '"swift-region"'

  sops --set '["objectStorage"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  yq_set sc .objectStorage.sync.enabled 'true'

  yq_set sc .objectStorage.sync.destinationType '"none"'
  yq_set sc .objectStorage.sync.syncDefaultBuckets 'false'

  yq_set sc .networkPolicies.rclone.enabled 'true'

  env.cache_create
}

teardown_file() {
  env.cache_delete

  gpg.teardown
}

setup() {
  load "../../../common/lib"
  load "../../../common/lib/env"
  load "../../../common/lib/update-ips"

  common_setup

  env.cache_restore

  update_ips.setup_mocks

  export mock_curl
  export mock_dig
  export mock_kubectl
}

# ---- setup -----------------------------------------------------------------------------------------------------------

_setup_s3() {
  update_ips.mock_rclone_s3

  yq_set sc "${1}" '"s3"'
  yq_set sc .objectStorage.sync.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'
}

_setup_s3_and_swift() {
  update_ips.mock_rclone_s3_and_swift

  yq_set sc "${1}" '"s3"'
  yq_set sc .objectStorage.sync.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'

  yq_set sc .objectStorage.sync.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq_set sc .objectStorage.sync.swift.region '"swift-region"'
  yq_set sc .objectStorage.sync.swift.domainName '"swift-domain"'
  yq_set sc .objectStorage.sync.swift.projectDomainName '"swift-project-domain"'
  yq_set sc .objectStorage.sync.swift.projectName '"swift-project"'

  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"
}

_setup_swift() {
  update_ips.mock_rclone_swift

  yq_set sc "${1}" '"swift"'
  yq_set sc .objectStorage.sync.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq_set sc .objectStorage.sync.swift.region '"swift-region"'
  yq_set sc .objectStorage.sync.swift.domainName '"swift-domain"'
  yq_set sc .objectStorage.sync.swift.projectDomainName '"swift-project-domain"'
  yq_set sc .objectStorage.sync.swift.projectName '"swift-project"'

  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"
}

_setup_swift_and_s3() {
  update_ips.mock_rclone_s3_and_swift

  yq_set sc "${1}" '"swift"'
  yq_set sc .objectStorage.sync.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq_set sc .objectStorage.sync.swift.region '"swift-region"'
  yq_set sc .objectStorage.sync.swift.domainName '"swift-domain"'
  yq_set sc .objectStorage.sync.swift.projectDomainName '"swift-project-domain"'
  yq_set sc .objectStorage.sync.swift.projectName '"swift-project"'

  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  yq_set sc .objectStorage.sync.s3.regionEndpoint '"https://s3.foo.dev-ck8s.com:1234"'
}

# --- s3 only ----------------------------------------------------------------------------------------------------------

_test_rclone_sync_s3_requires_s3_endpoint() {
  yq_set sc "${1}" '"s3"'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.s3.regionEndpoint is not configured"

  update_ips.assert_none
}

@test "rclone sync - s3 - requires s3 endpoint - buckets destination type" {
  _test_rclone_sync_s3_requires_s3_endpoint '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - s3 - requires s3 endpoint - sync destination type" {
  _test_rclone_sync_s3_requires_s3_endpoint '.objectStorage.sync.destinationType'
}

_test_apply_rclone_sync_s3() {
  _setup_s3 "${1}"

  run ck8s update-ips both apply

  update_ips.assert_rclone_s3
}

@test "rclone sync - s3 - buckets destination type" {
  _test_apply_rclone_sync_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - s3 - sync destination type" {
  _test_apply_rclone_sync_s3 '.objectStorage.sync.destinationType'
}

# --- s3 remove swift --------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_s3_remove_swift() {
  _setup_s3 "${1}"

  yq_set sc .networkPolicies.rclone.sync.objectStorageSwift.ips '["127.0.0.5/32"]'
  yq_set sc .networkPolicies.rclone.sync.objectStorageSwift.ports '[5678]'

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorageSwift' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  update_ips.assert_rclone_s3
}

@test "rclone sync - s3 and remove swift - buckets destination type" {
  _test_apply_rclone_sync_s3_remove_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - s3 and remove swift - sync destination type" {
  _test_apply_rclone_sync_s3_remove_swift '.objectStorage.sync.destinationType'
}

# --- s3 add swift -----------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_s3_add_swift() {
  _setup_s3_and_swift "${1}"

  run ck8s update-ips both apply

  update_ips.assert_rclone_s3_and_swift
}

@test "rclone sync - s3 and add swift - buckets destination type" {
  _test_apply_rclone_sync_s3_add_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - s3 and add swift - sync destination type" {
  _test_apply_rclone_sync_s3_add_swift '.objectStorage.sync.destinationType'
}

# --- swift -----------------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_swift_requires_swift_endpoint() {
  _setup_swift "${1}"

  yq_set sc .objectStorage.sync.swift.authUrl '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.swift.authUrl is not configured"

  update_ips.assert_none
}

@test "rclone sync - swift - requires swift endpoint - buckets destination type" {
  _test_apply_rclone_sync_swift_requires_swift_endpoint '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - swift - requires swift endpoint - sync destination type" {
  _test_apply_rclone_sync_swift_requires_swift_endpoint '.objectStorage.sync.destinationType'
}

@test "rclone sync - swift - requires swift endpoint - harbor" {
  yq_set sc .objectStorage.sync.syncDefaultBuckets "true"

  _test_apply_rclone_sync_swift_requires_swift_endpoint '.harbor.persistence.type'
}

@test "rclone sync - swift - requires swift endpoint - thanos" {
  yq_set sc .objectStorage.sync.syncDefaultBuckets "true"

  _test_apply_rclone_sync_swift_requires_swift_endpoint '.thanos.objectStorage.type'
}

_test_apply_rclone_sync_swift() {
  _setup_swift "${1}"

  run ck8s update-ips both apply

  update_ips.assert_rclone_swift
}

@test "rclone sync - swift - buckets destination type" {
  _test_apply_rclone_sync_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - swift - sync destination type" {
  _test_apply_rclone_sync_swift '.objectStorage.sync.destinationType'
}

# --- swift remove s3 --------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_swift_remove_s3() {
  _setup_swift "${1}"

  yq_set sc .networkPolicies.rclone.sync.objectStorage.ips '["127.0.0.5/32"]'
  yq_set sc .networkPolicies.rclone.sync.objectStorage.ports '[5678]'

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorage' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  update_ips.assert_rclone_swift
}

@test "rclone sync - swift and remove s3 - buckets destination type" {
  _test_apply_rclone_sync_swift_remove_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - swift and remove s3 - sync destination type" {
  _test_apply_rclone_sync_swift_remove_s3 '.objectStorage.sync.destinationType'
}


# --- swift add s3 -----------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_swift_add_s3() {
  _setup_swift_and_s3 "${1}"

  run ck8s update-ips both apply

  update_ips.assert_rclone_s3_and_swift
}

@test "rclone sync - swift and add s3 - buckets destination type" {
  _test_apply_rclone_sync_swift_add_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - swift and add s3 - sync destination type" {
  _test_apply_rclone_sync_swift_add_s3 '.objectStorage.sync.destinationType'
}

# --- s3 and swift -----------------------------------------------------------------------------------------------------

_test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint() {
  yq_set sc .objectStorage.sync.s3.regionEndpoint '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.s3.regionEndpoint is not configured"

  update_ips.assert_none
}

@test "rclone sync - s3 and swift requires s3 endpoint - s3" {
  _setup_s3_and_swift '.objectStorage.sync.destinationType'
  yq_set sc .objectStorage.sync.buckets.[0].destinationType '"s3"'
  yq_set sc .objectStorage.sync.buckets.[1].destinationType '"swift"'

  _test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint
}

@test "rclone sync - s3 and swift requires s3 endpoint - swift" {
  _setup_swift_and_s3 '.objectStorage.sync.destinationType'
  yq_set sc .objectStorage.sync.buckets.[0].destinationType '"swift"'
  yq_set sc .objectStorage.sync.buckets.[1].destinationType '"s3"'

  _test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint
}

_test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint() {
  yq_set sc .objectStorage.sync.swift.authUrl '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.swift.authUrl is not configured"

  update_ips.assert_none
}

@test "rclone sync - s3 and swift requires swift endpoint - s3" {
  _setup_s3_and_swift '.objectStorage.sync.destinationType'
  yq_set sc .objectStorage.sync.buckets.[0].destinationType '"s3"'
  yq_set sc .objectStorage.sync.buckets.[1].destinationType '"swift"'

  _test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint
}

@test "rclone sync - s3 and swift requires swift endpoint - swift" {
  _setup_swift_and_s3 '.objectStorage.sync.destinationType'
  yq_set sc .objectStorage.sync.buckets.[0].destinationType '"swift"'
  yq_set sc .objectStorage.sync.buckets.[1].destinationType '"s3"'

  _test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint
}

_test_apply_rclone_sync_s3_and_swift() {
  run ck8s update-ips both apply

  update_ips.assert_rclone_s3_and_swift
}

@test "rclone sync - s3 and swift - s3" {
  _setup_s3_and_swift '.objectStorage.sync.destinationType'
  yq_set sc .objectStorage.sync.buckets.[0].destinationType '"s3"'
  yq_set sc .objectStorage.sync.buckets.[1].destinationType '"swift"'

  _test_apply_rclone_sync_s3_and_swift
}

@test "rclone sync - s3 and swift - swift" {
  _setup_swift_and_s3 '.objectStorage.sync.destinationType'
  yq_set sc .objectStorage.sync.buckets.[0].destinationType '"swift"'
  yq_set sc .objectStorage.sync.buckets.[1].destinationType '"s3"'

  _test_apply_rclone_sync_s3_and_swift
}

# --- secondary --------------------------------------------------------------------------------------------------------

@test "rclone sync - secondary add" {
  yq_set sc .objectStorage.sync.secondaryUrl '"https://s3.foo.dev-ck8s.com:1234"'

  update_ips.mock_minimal
  mock_set_output "${mock_dig}" "127.0.0.4" 4 # .objectStorage.sync.secondaryUrl

  run ck8s update-ips both apply

  assert_equal "$(yq_dig sc '.networkPolicies.rclone.sync.secondaryUrl.ips | . style="flow"')" "[127.0.0.4/32]"
  assert_equal "$(yq_dig sc '.networkPolicies.rclone.sync.secondaryUrl.ports | . style="flow"')" "[1234]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 4
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "rclone sync - secondary remove" {
  yq_set sc .networkPolicies.rclone.sync.secondaryUrl.ips '["127.0.0.4"]'
  yq_set sc .networkPolicies.rclone.sync.secondaryUrl.ports '[1234]'

  update_ips.mock_minimal
  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.secondaryUrl' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

# --- get-swift-url ----------------------------------------------------------------------------------------------------

@test "rclone sync - get-swift-url" {
  _setup_swift '.objectStorage.sync.destinationType'

  mock_set_output "${mock_dig}" ""

  run ck8s update-ips both apply

  assert_equal "$(mock_get_call_args "${mock_curl}" 1)" "$(cat "${BATS_TEST_DIRNAME}/resources/get-swift-url.out")"
}
