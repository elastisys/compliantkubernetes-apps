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

  yq_set sc .objectStorage.swift.authUrl '"https://keystone.foo.dev-ck8s.com:5678"'
  yq_set sc .objectStorage.swift.region '"swift-region"'
  yq_set sc .objectStorage.swift.domainName '"swift-domain"'
  yq_set sc .objectStorage.swift.projectDomainName '"swift-project-domain"'
  yq_set sc .objectStorage.swift.projectName '"swift-project"'
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

_test_requires_auth_endpoint() {
  yq_set sc "${1}" '"swift"'
  yq_set sc  .objectStorage.swift.authUrl '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.swift.authUrl is not configured"

  update_ips.assert_mocks_none
}

@test "update-ips - swift - requires auth endpoint - harbor" {
  _test_requires_auth_endpoint '.harbor.persistence.type'
}

@test "update-ips - swift - requires auth endpoint - thanos" {
  _test_requires_auth_endpoint '.thanos.objectStorage.type'
}

@test "update-ips - swift - requires auth endpoint - bucket source type" {
  _test_requires_auth_endpoint '.objectStorage.sync.buckets.[0].sourceType'
}

_test_requires_region() {
  yq_set sc "${1}" '"swift"'
  yq_set sc .objectStorage.swift.region '""'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial ".objectStorage.swift.region is not configured"

  update_ips.assert_none
}

@test "update-ips - swift - requires region - harbor" {
  _test_requires_region '.harbor.persistence.type'
}

@test "update-ips - swift - requires region - thanos" {
  _test_requires_region '.thanos.objectStorage.type'
}

@test "update-ips - swift - requires region - bucket source type" {
  _test_requires_region '.objectStorage.sync.buckets.[0].sourceType'
}

_test_requires_username_or_application_credential_id() {
  yq_set sc "${1}" '"swift"'

  run ck8s update-ips both apply
  assert_failure
  assert_output --partial "No Swift username or application credential ID"

  update_ips.assert_none
}

@test "update-ips - swift - requires username or application credential id - harbor" {
  _test_requires_username_or_application_credential_id '.harbor.persistence.type'
}

@test "update-ips - swift - requires username or application credential id - thanos" {
  _test_requires_username_or_application_credential_id '.thanos.objectStorage.type'
}

@test "update-ips - swift - requires username or application credential id - bucket source type" {
  _test_requires_username_or_application_credential_id '.objectStorage.sync.buckets.[0].sourceType'
}

_test_apply_swift_username() {
  yq_set sc "${1}" '"swift"'

  update_ips.mock_swift

  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  run ck8s update-ips both apply

  update_ips.assert_swift
}

@test "update-ips - swift - username - harbor" {
  _test_apply_swift_username '.harbor.persistence.type'
}

@test "update-ips - swift - username - thanos" {
  _test_apply_swift_username '.thanos.objectStorage.type'
}

@test "update-ips - swift - username - bucket source type" {
  _test_apply_swift_username '.objectStorage.sync.buckets.[0].sourceType'
}

_test_apply_swift_application_credential_id() {
  yq_set sc "${1}" '"swift"'

  update_ips.mock_swift

  sops --set '["objectStorage"]["swift"]["applicationCredentialID"] "swift-application-credential-id"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  run ck8s update-ips both apply

  update_ips.assert_swift
}

@test "update-ips - swift - application credential id - harbor" {
  _test_apply_swift_application_credential_id '.harbor.persistence.type'
}

@test "update-ips - swift - application credential id - thanos" {
  _test_apply_swift_application_credential_id '.thanos.objectStorage.type'
}

@test "update-ips - swift - application credential id - bucket source type" {
  _test_apply_swift_application_credential_id '.objectStorage.sync.buckets.[0].sourceType'
}

@test "update-ips - swift - get-swift-url" {
  yq_set sc .harbor.persistence.type '"swift"'

  update_ips.mock_swift

  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  run ck8s update-ips both apply

  assert_equal "$(mock_get_call_args "${mock_curl}" 1)" "$(cat "${BATS_TEST_DIRNAME}/resources/get-swift-url.out")"
}
