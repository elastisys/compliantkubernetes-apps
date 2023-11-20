#!/usr/bin/env bats

set -ueo pipefail

setup() {
  load "bats-helpers/bats-support/load"
  load "bats-helpers/bats-assert/load"
  load "bats-helpers/bats-mock/load"

  export PATH="${BATS_TEST_DIRNAME}/../bin:${PATH}"

  ck8s_config_path_tmp="${BATS_TMPDIR}/ck8s-apps-config"

  export CK8S_CONFIG_PATH="${ck8s_config_path_tmp}"

  mkdir -p "${ck8s_config_path_tmp}/defaults"
  touch "${ck8s_config_path_tmp}/defaults/common-config.yaml"
  touch "${ck8s_config_path_tmp}/defaults/sc-config.yaml"
  touch "${ck8s_config_path_tmp}/common-config.yaml"
  touch "${ck8s_config_path_tmp}/sc-config.yaml"
  touch "${ck8s_config_path_tmp}/wc-config.yaml"
  echo 'foo: bar' | sops -p "${CK8S_PGP_FP}" --input-type yaml -e /dev/stdin > "${ck8s_config_path_tmp}/secrets.yaml"
  mkdir -p "${ck8s_config_path_tmp}/.state"
  touch "${ck8s_config_path_tmp}/.state/kube_config_sc.yaml"
  touch "${ck8s_config_path_tmp}/.state/kube_config_wc.yaml"

  mock_dig="$(mock_create)"
  export mock_dig
  dig() {
    # shellcheck disable=SC2317
    "${mock_dig}" "${@}"
  }
  export -f dig

  mock_kubectl="$(mock_create)"
  export mock_kubectl
  kubectl() {
    # shellcheck disable=SC2317
    "${mock_kubectl}" "${@}"
  }
  export -f kubectl

  mock_curl="$(mock_create)"
  export mock_curl
  curl() {
    # shellcheck disable=SC2317
    "${mock_curl}" "${@}"
  }
  export -f curl
}

teardown() {
  rm -rf "${ck8s_config_path_tmp}"
}

#
# BASIC
#

@test "basic config requires CK8S_CONFIG_PATH" {
  CK8S_CONFIG_PATH="" run ck8s update-ips both apply
  assert_failure
  assert_output --partial "Missing CK8S_CONFIG_PATH"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "basic config requires .objectStorage.s3.regionEndpoint" {
  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.s3.regionEndpoint is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "basic config requires .global.opsDomain" {
  yq4 -i '.objectStorage.s3.regionEndpoint = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/common-config.yaml"

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".global.opsDomain is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "basic config requires .global.baseDomain" {
  yq4 -i '.objectStorage.s3.regionEndpoint = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq4 -i '.global.opsDomain = "ops.dev-ck8s.com"'  "${CK8S_CONFIG_PATH}/common-config.yaml"

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".global.baseDomain is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

_setup_basic() {
  yq4 -i '.objectStorage.s3.regionEndpoint = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq4 -i '.global.opsDomain = "ops.dev-ck8s.com"' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq4 -i '.global.baseDomain = "dev-ck8s.com"' "${CK8S_CONFIG_PATH}/common-config.yaml"

  mock_set_output "${mock_dig}" "127.0.0.1" 1 # .networkPolicies.global.objectStorage.ips
  mock_set_output "${mock_dig}" "127.0.0.2" 2 # .networkPolicies.global.scIngress.ips
  mock_set_output "${mock_dig}" "127.0.0.3" 3 # .networkPolicies.global.wcIngress.ips

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1" 1 # .networkPolicies.global.scApiserver.ips IPS_internal
  mock_set_output "${mock_kubectl}" "127.0.1.2 127.0.2.2 127.0.3.2" 2 # .networkPolicies.global.scApiserver.ips IPS_calico
  mock_set_output "${mock_kubectl}" "127.0.1.3 127.0.2.3 127.0.3.3" 3 # .networkPolicies.global.scApiserver.ips IPS_wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.7 127.0.2.7 127.0.3.7" 4 # .networkPolicies.global.scNodes.ips IPS_internal
  mock_set_output "${mock_kubectl}" "127.0.1.8 127.0.2.8 127.0.3.8" 5 # .networkPolicies.global.scNodes.ips IPS_calico
  mock_set_output "${mock_kubectl}" "127.0.1.9 127.0.2.9 127.0.3.9" 6 # .networkPolicies.global.scNodes.ips IPS_wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.4 127.0.2.4 127.0.3.4" 7 # .networkPolicies.global.wcApiserver.ips IPS_internal
  mock_set_output "${mock_kubectl}" "127.0.1.5 127.0.2.5 127.0.3.5" 8 # .networkPolicies.global.wcApiserver.ips IPS_calico
  mock_set_output "${mock_kubectl}" "127.0.1.6 127.0.2.6 127.0.3.6" 9 # .networkPolicies.global.wcApiserver.ips IPS_wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.10 127.0.2.10 127.0.3.10" 10 # .networkPolicies.global.wcNodes.ips IPS_internal
  mock_set_output "${mock_kubectl}" "127.0.1.11 127.0.2.11 127.0.3.11" 11 # .networkPolicies.global.wcNodes.ips IPS_calico
  mock_set_output "${mock_kubectl}" "127.0.1.12 127.0.2.12 127.0.3.12" 12 # .networkPolicies.global.wcNodes.ips IPS_wireguard
}

@test "basic config" {
  _setup_basic

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.global.objectStorage | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/common-config.yaml")" "[127.0.0.1/32]"
  assert_equal "$(yq4 '.networkPolicies.global.objectStorage | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/common-config.yaml")" "[1234]"
  assert_equal "$(yq4 '.networkPolicies.global.scIngress | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/common-config.yaml")" "[127.0.0.2/32]"
  assert_equal "$(yq4 '.networkPolicies.global.wcIngress | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/common-config.yaml")" "[127.0.0.3/32]"
  assert_equal "$(yq4 '.networkPolicies.global.scApiserver | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.1.1/32, 127.0.1.2/32, 127.0.1.3/32, 127.0.2.1/32, 127.0.2.2/32, 127.0.2.3/32, 127.0.3.1/32, 127.0.3.2/32, 127.0.3.3/32]"
  assert_equal "$(yq4 '.networkPolicies.global.wcApiserver | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/wc-config.yaml")" "[127.0.1.4/32, 127.0.1.5/32, 127.0.1.6/32, 127.0.2.4/32, 127.0.2.5/32, 127.0.2.6/32, 127.0.3.4/32, 127.0.3.5/32, 127.0.3.6/32]"
  assert_equal "$(yq4 '.networkPolicies.global.scNodes | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.1.7/32, 127.0.1.8/32, 127.0.1.9/32, 127.0.2.7/32, 127.0.2.8/32, 127.0.2.9/32, 127.0.3.7/32, 127.0.3.8/32, 127.0.3.9/32]"
  assert_equal "$(yq4 '.networkPolicies.global.wcNodes | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/wc-config.yaml")" "[127.0.1.10/32, 127.0.1.11/32, 127.0.1.12/32, 127.0.2.10/32, 127.0.2.11/32, 127.0.2.12/32, 127.0.3.10/32, 127.0.3.11/32, 127.0.3.12/32]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

#
# SWIFT
#

_test_swift_requires_openstack_auth_endpoint() {
  _setup_basic

  yq4 -i "${1}"' = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.swift.authUrl is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "swift requires openstack auth endpoint - harbor" {
  _test_swift_requires_openstack_auth_endpoint '.harbor.persistence.type'
}

@test "swift requires openstack auth endpoint - thanos" {
  _test_swift_requires_openstack_auth_endpoint '.thanos.objectStorage.type'
}

@test "swift requires openstack auth endpoint - bucket source type" {
  _test_swift_requires_openstack_auth_endpoint '.objectStorage.sync.buckets.[0].sourceType'
}

_test_swift_requires_swift_region() {
  _setup_basic

  yq4 -i "${1}"' = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.authUrl = "https://keystone.foo.dev-ck8s.com"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # $os_auth_endpoint

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.swift.region is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "swift requires swift region - harbor" {
  _test_swift_requires_swift_region '.harbor.persistence.type'
}

@test "swift requires swift region - thanos" {
  _test_swift_requires_swift_region '.thanos.objectStorage.type'
}

@test "swift requires swift region - bucket source type" {
  _test_swift_requires_swift_region '.objectStorage.sync.buckets.[0].sourceType'
}

_test_swift_requires_username_or_application_credential_id() {
  _setup_basic

  yq4 -i "${1}"' = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.authUrl = "https://keystone.foo.dev-ck8s.com"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.region = "swift-region"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # $os_auth_endpoint

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial "No Swift username or application credential ID"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "swift requires username or application credential id - harbor" {
  _test_swift_requires_username_or_application_credential_id '.harbor.persistence.type'
}

@test "swift requires username or application credential id - thanos" {
  _test_swift_requires_username_or_application_credential_id '.thanos.objectStorage.type'
}

@test "swift requires username or application credential id - bucket source type" {
  _test_swift_requires_username_or_application_credential_id '.objectStorage.sync.buckets.[0].sourceType'
}

_setup_swift() {
  _setup_basic

  yq4 -i "${1}"' = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.authUrl = "https://keystone.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.region = "swift-region"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # $os_auth_endpoint
  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com:91011"}]}]}]' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens
  mock_set_output "${mock_dig}" "127.0.0.5" 5 # $swift_endpoint
}

_test_apply_swift_username() {
  _setup_swift "${1}"

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.global.objectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32, 127.0.0.5/32]"
  assert_equal "$(yq4 '.networkPolicies.global.objectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[5678, 91011]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 5
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

@test "swift username - harbor" {
  _test_apply_swift_username '.harbor.persistence.type'
}

@test "swift username - thanos" {
  _test_apply_swift_username '.thanos.objectStorage.type'
}

@test "swift username - bucket source type" {
  _test_apply_swift_username '.objectStorage.sync.buckets.[0].sourceType'
}

_test_apply_swift_application_credential_id() {
  _setup_basic

  yq4 -i "${1}"' = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.authUrl = "https://keystone.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.region = "swift-region"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  sops --set '["objectStorage"]["swift"]["applicationCredentialID"] "swift-application-credential-id"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # $os_auth_endpoint
  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com:91011"}]}]}]' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens
  mock_set_output "${mock_dig}" "127.0.0.5" 5 # $swift_endpoint

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.global.objectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32, 127.0.0.5/32]"
  assert_equal "$(yq4 '.networkPolicies.global.objectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[5678, 91011]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 5
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

@test "swift application credential id - harbor" {
  _test_apply_swift_application_credential_id '.harbor.persistence.type'
}

@test "swift application credential id - thanos" {
  _test_apply_swift_application_credential_id '.thanos.objectStorage.type'
}

@test "swift application credential id - bucket source type" {
  _test_apply_swift_application_credential_id '.objectStorage.sync.buckets.[0].sourceType'
}

#
# RCLONE - S3
#

_setup_rclone() {
  _setup_basic

  yq4 -i '.objectStorage.sync.enabled = "true"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.networkPolicies.rcloneSync.enabled = "true"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
}

_test_rclone_sync_s3_requires_s3_endpoint() {
  _setup_rclone

  yq4 -i "${1}"' = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.s3.regionEndpoint is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "rclone sync - s3 requires s3 endpoint - buckets destination type" {
  _test_rclone_sync_s3_requires_s3_endpoint '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - s3 requires s3 endpoint - sync destination type" {
  _test_rclone_sync_s3_requires_s3_endpoint '.objectStorage.sync.destinationType'
}

_setup_rclone_sync_s3() {
  _setup_rclone

  yq4 -i '.objectStorage.sync.s3.regionEndpoint = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i "${1}"' = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # $S3_ENDPOINT_DST
}

_test_apply_rclone_sync_s3() {
  _setup_rclone_sync_s3 "${1}"

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[1234]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 4
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "rclone sync - s3 - buckets destination type" {
  _test_apply_rclone_sync_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - s3 - sync destination type" {
  _test_apply_rclone_sync_s3 '.objectStorage.sync.destinationType'
}

#
# RCLONE - S3 - REMOVE SWIFT
#

_test_apply_rclone_sync_s3_remove_swift() {
  _setup_rclone_sync_s3 "${1}"

  yq4 -i '.networkPolicies.rcloneSync.destinationObjectStorageSwift.ips[0] = "127.0.0.5/32"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.networkPolicies.rcloneSync.destinationObjectStorageSwift.ports[0] = 5678' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[1234]"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 4
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "rclone sync - s3 and remove swift - buckets destination type" {
  _test_apply_rclone_sync_s3_remove_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - s3 and remove swift - sync destination type" {
  _test_apply_rclone_sync_s3_remove_swift '.objectStorage.sync.destinationType'
}

#
# RCLONE - S3 - ADD SWIFT
#

_test_apply_rclone_sync_s3_add_swift() {
  _setup_rclone_sync_s3 "${1}"

  yq4 -i '.objectStorage.sync.swift.authUrl = "https://keystone.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  mock_set_output "${mock_dig}" "127.0.0.5" 5 # $os_auth_host
  mock_set_output "${mock_dig}" "127.0.0.6" 6 # $swift_host

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[1234]"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.5/32, 127.0.0.6/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 5678]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 6
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

@test "rclone sync - s3 and add swift - buckets destination type" {
  _test_apply_rclone_sync_s3_add_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - s3 and add swift - sync destination type" {
  _test_apply_rclone_sync_s3_add_swift '.objectStorage.sync.destinationType'
}

#
# RCLONE - SWIFT
#

_test_apply_rclone_sync_swift_requires_swift_endpoint() {
  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.swift.authUrl is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "rclone sync - swift - requires swift endpoint - buckets destination type" {
  _setup_rclone
  yq4 -i '.objectStorage.sync.buckets.[0].destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  _test_apply_rclone_sync_swift_requires_swift_endpoint
}

@test "rclone sync - swift - requires swift endpoint - sync destination type" {
  _setup_rclone
  yq4 -i '.objectStorage.sync.destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  _test_apply_rclone_sync_swift_requires_swift_endpoint
}

@test "rclone sync - swift - requires swift endpoint - harbor" {
  _setup_swift '.harbor.persistence.type'
  _setup_rclone
  yq4 -i '.objectStorage.sync.syncDefaultBuckets = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  _test_apply_rclone_sync_swift_requires_swift_endpoint
}

@test "rclone sync - swift - requires swift endpoint - thanos" {
  _setup_swift '.thanos.objectStorage.type'
  _setup_rclone
  yq4 -i '.objectStorage.sync.syncDefaultBuckets = true' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  _test_apply_rclone_sync_swift_requires_swift_endpoint
}

_setup_rclone_sync_swift() {
  _setup_rclone

  yq4 -i '.objectStorage.sync.swift.authUrl = "https://keystone.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  yq4 -i "${1}"' = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # $os_auth_host
  mock_set_output "${mock_dig}" "127.0.0.5" 5 # $swift_host
}

_test_apply_rclone_sync_swift() {
  _setup_rclone_sync_swift "${1}"

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32, 127.0.0.5/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 1234]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 5
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

@test "rclone sync - swift - buckets destination type" {
  _test_apply_rclone_sync_swift '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - swift - sync destination type" {
  _test_apply_rclone_sync_swift '.objectStorage.sync.destinationType'
}

#
# RCLONE - SWIFT - REMOVE S3
#

_test_apply_rclone_sync_swift_remove_s3() {
  _setup_rclone_sync_swift "${1}"

  yq4 -i '.networkPolicies.rcloneSync.destinationObjectStorageS3.ips[0] = "127.0.0.5/32"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.networkPolicies.rcloneSync.destinationObjectStorageS3.ports[0] = 5678' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32, 127.0.0.5/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 1234]"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 5
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

@test "rclone sync - swift and remove s3 - buckets destination type" {
  _test_apply_rclone_sync_swift_remove_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - swift and remove s3 - sync destination type" {
  _test_apply_rclone_sync_swift_remove_s3 '.objectStorage.sync.destinationType'
}

#
# RCLONE - SWIFT - ADD S3
#

_test_apply_rclone_sync_swift_add_s3() {
  _setup_rclone

  yq4 -i '.objectStorage.sync.swift.authUrl = "https://keystone.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  yq4 -i "${1}"' = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.s3.regionEndpoint = "https://s3.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  mock_set_output "${mock_dig}" "127.0.0.5" 4 # $S3_ENDPOINT_DST
  mock_set_output "${mock_dig}" "127.0.0.4" 5 # $os_auth_host
  mock_set_output "${mock_dig}" "127.0.0.6" 6 # $swift_host

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32, 127.0.0.6/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 1234]"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.5/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[5678]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 6
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

@test "rclone sync - swift and add s3 - buckets destination type" {
  _test_apply_rclone_sync_swift_add_s3 '.objectStorage.sync.buckets.[0].destinationType'
}

@test "rclone sync - swift and add s3 - sync destination type" {
  _test_apply_rclone_sync_swift_add_s3 '.objectStorage.sync.destinationType'
}

#
# RCLONE - S3 AND SWIFT
#

_test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint() {
  _setup_rclone

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.s3.regionEndpoint is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "rclone sync - s3 and swift requires s3 endpoint - s3" {
  yq4 -i '.objectStorage.sync.destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[0].destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[1].destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  _test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint
}

@test "rclone sync - s3 and swift requires s3 endpoint - swift" {
  yq4 -i '.objectStorage.sync.destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[0].destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[1].destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  _test_apply_rclone_sync_s3_and_swift_requires_s3_endpoint
}

_test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint() {
  _setup_rclone

  yq4 -i '.objectStorage.sync.s3.regionEndpoint = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.sync.swift.authUrl is not configured"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "rclone sync - s3 and swift requires swift endpoint - s3" {
  yq4 -i '.objectStorage.sync.destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[0].destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[1].destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  _test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint
}

@test "rclone sync - s3 and swift requires swift endpoint - swift" {
  yq4 -i '.objectStorage.sync.destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[0].destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[1].destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  _test_apply_rclone_sync_s3_and_swift_requires_swift_endpoint
}

_test_apply_rclone_sync_s3_and_swift() {
  _setup_rclone

  yq4 -i '.objectStorage.sync.s3.regionEndpoint = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.swift.authUrl = "https://keystone.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # $S3_ENDPOINT_DST
  mock_set_output "${mock_dig}" "127.0.0.5" 5 # $os_auth_host
  mock_set_output "${mock_dig}" "127.0.0.6" 6 # $swift_host

  run ck8s update-ips both apply

  # Note how the outcome is the same as for the test "ck8s update-ips both apply - rclone sync - s3 and add swift"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[1234]"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.5/32, 127.0.0.6/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 5678]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 6
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

@test "rclone sync - s3 and swift - s3" {
  yq4 -i '.objectStorage.sync.destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[0].destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[1].destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  _test_apply_rclone_sync_s3_and_swift
}

@test "rclone sync - s3 and swift - swift" {
  yq4 -i '.objectStorage.sync.destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[0].destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.buckets.[1].destinationType = "s3"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  _test_apply_rclone_sync_s3_and_swift
}

#
# RCLONE - SECONDARY
#

@test "rclone sync - secondary add" {
  _setup_rclone

  yq4 -i '.objectStorage.sync.secondaryUrl = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # $SECONDARY_ENDPOINT

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.secondaryUrl | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.secondaryUrl | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[1234]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 4
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "rclone sync - secondary remove" {
  _setup_rclone

  yq4 -i '.networkPolicies.rcloneSync.secondaryUrl.ips[0] = "127.0.0.4"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.networkPolicies.rcloneSync.secondaryUrl.ports[0] = 1234' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.secondaryUrl' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

#
# Other
#

_setup_basic_with_zero_diff() {
  _setup_basic

  yq4 -i '.networkPolicies.global.objectStorage.ips = ["127.0.0.1/32"]' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq4 -i '.networkPolicies.global.objectStorage.ports = [1234]' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq4 -i '.networkPolicies.global.scIngress.ips = ["127.0.0.2/32"]' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq4 -i '.networkPolicies.global.wcIngress.ips = ["127.0.0.3/32"]' "${CK8S_CONFIG_PATH}/common-config.yaml"
  yq4 -i '.networkPolicies.global.scApiserver.ips = ["127.0.1.1/32", "127.0.1.2/32", "127.0.1.3/32", "127.0.2.1/32", "127.0.2.2/32", "127.0.2.3/32", "127.0.3.1/32", "127.0.3.2/32", "127.0.3.3/32"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.networkPolicies.global.wcApiserver.ips = ["127.0.1.4/32", "127.0.1.5/32", "127.0.1.6/32", "127.0.2.4/32", "127.0.2.5/32", "127.0.2.6/32", "127.0.3.4/32", "127.0.3.5/32", "127.0.3.6/32"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
  yq4 -i '.networkPolicies.global.scNodes.ips = ["127.0.1.7/32", "127.0.1.8/32", "127.0.1.9/32", "127.0.2.7/32", "127.0.2.8/32", "127.0.2.9/32", "127.0.3.7/32", "127.0.3.8/32", "127.0.3.9/32"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.networkPolicies.global.wcNodes.ips = ["127.0.1.10/32", "127.0.1.11/32", "127.0.1.12/32", "127.0.2.10/32", "127.0.2.11/32", "127.0.2.12/32", "127.0.3.10/32", "127.0.3.11/32", "127.0.3.12/32"]' "${CK8S_CONFIG_PATH}/wc-config.yaml"
}

@test "sorting ips" {
  _setup_basic_with_zero_diff

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1 126.0.0.20 126.0.0.3" 1 # .networkPolicies.global.scApiserver.ips IPS_internal

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.global.scApiserver | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[126.0.0.3/32, 126.0.0.20/32, 127.0.1.1/32, 127.0.1.2/32, 127.0.1.3/32, 127.0.2.1/32, 127.0.2.2/32, 127.0.2.3/32, 127.0.3.1/32, 127.0.3.2/32, 127.0.3.3/32]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

@test "ips part of existing cidrs" {
  _setup_basic_with_zero_diff

  yq4 -i '.networkPolicies.global.scApiserver.ips = ["127.0.0.0/16", "127.1.0.0/16"]' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1 127.1.0.0 127.1.0.1 127.2.0.1" 1 # .networkPolicies.global.scApiserver.ips IPS_internal

  run ck8s update-ips both apply

  assert_equal "$(yq4 '.networkPolicies.global.scApiserver | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.0/16, 127.1.0.0/16, 127.2.0.1/32]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 12
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

#
# Dry running
#

_setup_full() {
  _setup_basic

  # Swift

  yq4 -i '.harbor.persistence.type = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.authUrl = "https://keystone.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.region = "swift-region"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  mock_set_output "${mock_dig}" "127.1.0.4" 4 # $os_auth_endpoint
  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com:91011"}]}]}]' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens
  mock_set_output "${mock_dig}" "127.1.0.5" 5 # $swift_endpoint

  # RClone

  yq4 -i '.objectStorage.sync.enabled = "true"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.networkPolicies.rcloneSync.enabled = "true"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.s3.regionEndpoint = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.swift.authUrl = "https://keystone.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-sync-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  yq4 -i '.objectStorage.sync.secondaryUrl = "https://s3.foo.dev-ck8s.com:1234"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  mock_set_output "${mock_dig}" "127.1.0.6" 6 # $S3_ENDPOINT_DST
  mock_set_output "${mock_dig}" "127.1.0.7" 7 # $os_auth_host
  mock_set_output "${mock_dig}" "127.1.0.8" 8 # $swift_host
  mock_set_output "${mock_dig}" "127.1.0.9" 9 # $SECONDARY_ENDPOINT
}

@test "dry-run full diff" {
  _setup_full

  run ck8s update-ips both dry-run
  assert_failure

  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/update-ips-dry-run-full-diff.out")"
}

@test "dry-run zero diff" {
  _setup_basic_with_zero_diff

  run ck8s update-ips both dry-run
  assert_success

  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/update-ips-dry-run-zero-diff.out")"
}

@test "get-swift-url" {
  _setup_basic

  yq4 -i '.harbor.persistence.type = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.authUrl = "https://keystone.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.region = "swift-region"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.domainName = "swift-domain"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.projectDomainName = "swift-project-domain"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.swift.projectName = "swift-project"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  mock_set_output "${mock_dig}" ""

  run ck8s update-ips both apply

  assert_equal "$(mock_get_call_args "${mock_curl}" 1)" "$(cat "${BATS_TEST_DIRNAME}/resources/get-swift-url.out")"
}

@test "get-swift-url sync" {
  _setup_rclone

  yq4 -i '.objectStorage.sync.destinationType = "swift"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.swift.authUrl = "https://keystone.foo.dev-ck8s.com:5678"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.swift.region = "swift-region"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.swift.domainName = "swift-domain"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.swift.projectDomainName = "swift-project-domain"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  yq4 -i '.objectStorage.sync.swift.projectName = "swift-project"' "${CK8S_CONFIG_PATH}/sc-config.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["sync"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  mock_set_output "${mock_dig}" ""

  run ck8s update-ips both apply

  assert_equal "$(mock_get_call_args "${mock_curl}" 1)" "$(cat "${BATS_TEST_DIRNAME}/resources/get-swift-url.out")"
}
