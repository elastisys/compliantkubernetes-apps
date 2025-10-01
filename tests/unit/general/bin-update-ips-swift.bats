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
  yq.set sc .objectStorage.swift.domainName '"swift-domain"'
  yq.set sc .objectStorage.swift.projectDomainName '"swift-project-domain"'
  yq.set sc .objectStorage.swift.projectName '"swift-project"'
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

_mock() {
  # GET /auth/tokens
  mock_set_output "${mock_curl}" $'HTTP/2 200\r
  date: Wed, 09 Oct 2024 14:14:40 GMT\r
  expires: -1\r
  cache-control: private, max-age=0\r
  content-type: text/html; charset=ISO-8859-1\r
  x-subject-token: 123456789\r
  accept-ranges: none\r
  vary: Accept-Encoding\r
  \r
  {"token":{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com:91011"}]}]}}' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens

  mock_set_output "${mock_dig}" "192.0.2.1" 1 # keystone endpoint
  mock_set_output "${mock_dig}" "192.0.2.2" 2 # swift endpoint
}

_test_requires_auth_endpoint() {
  yq.set sc "${1}" '"swift"'
  yq.set sc .objectStorage.swift.authUrl '""'

  run ck8s update-ips both apply --enable swift
  assert_failure
  assert_output --partial ".objectStorage.swift.authUrl is not configured"

  update_ips.assert_mocks_none
}

@test "ck8s update-ips requires auth endpoint for swift - harbor" {
  _test_requires_auth_endpoint '.harbor.persistence.type'
}

@test "ck8s update-ips requires auth endpoint for swift - thanos" {
  _test_requires_auth_endpoint '.thanos.objectStorage.type'
}

@test "ck8s update-ips requires auth endpoint for swift - rclone sync bucket source type" {
  _test_requires_auth_endpoint '.objectStorage.sync.buckets.[0].sourceType'
}

_test_requires_region() {
  yq.set sc "${1}" '"swift"'
  yq.set sc .objectStorage.swift.region '""'

  run ck8s update-ips both apply --enable swift
  assert_failure
  assert_output --partial ".objectStorage.swift.region is not configured"

  update_ips.assert_mocks_none
}

@test "ck8s update-ips requires region for swift - harbor" {
  _test_requires_region '.harbor.persistence.type'
}

@test "ck8s update-ips requires region for swift - thanos" {
  _test_requires_region '.thanos.objectStorage.type'
}

@test "ck8s update-ips requires region for swift - rclone sync bucket source type" {
  _test_requires_region '.objectStorage.sync.buckets.[0].sourceType'
}

_test_requires_username_or_application_credential_id() {
  yq.set sc "${1}" '"swift"'

  run ck8s update-ips both apply --enable swift
  assert_failure
  assert_output --partial "No Swift username or application credential ID"

  update_ips.assert_mocks_none
}

@test "ck8s update-ips requires username or application credential id for swift - harbor" {
  _test_requires_username_or_application_credential_id '.harbor.persistence.type'
}

@test "ck8s update-ips requires username or application credential id for swift - thanos" {
  _test_requires_username_or_application_credential_id '.thanos.objectStorage.type'
}

@test "ck8s update-ips requires username or application credential id for swift - rclone sync bucket source type" {
  _test_requires_username_or_application_credential_id '.objectStorage.sync.buckets.[0].sourceType'
}

_test_apply_swift_username() {
  yq.set sc "${1}" '"swift"'

  _mock

  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  run ck8s update-ips both apply --enable swift

  assert_equal "$(yq.dig sc '.networkPolicies.global.objectStorageSwift.ips | . style="flow"')" "[192.0.2.1/32, 192.0.2.2/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.objectStorageSwift.ports | . style="flow"')" "[5678, 91011]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips sets swift using username - harbor" {
  _test_apply_swift_username '.harbor.persistence.type'
}

@test "ck8s update-ips sets swift using username - thanos" {
  _test_apply_swift_username '.thanos.objectStorage.type'
}

@test "ck8s update-ips sets swift using username - rclone sync bucket source type" {
  _test_apply_swift_username '.objectStorage.sync.buckets.[0].sourceType'
}

_test_apply_swift_application_credential_id() {
  yq.set sc "${1}" '"swift"'

  _mock

  sops --set '["objectStorage"]["swift"]["applicationCredentialID"] "swift-application-credential-id"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  run ck8s update-ips both apply --enable swift

  assert_equal "$(yq.dig sc '.networkPolicies.global.objectStorageSwift.ips | . style="flow"')" "[192.0.2.1/32, 192.0.2.2/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.objectStorageSwift.ports | . style="flow"')" "[5678, 91011]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
  assert_equal "$(mock_get_call_num "${mock_dig}")" 2
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

@test "ck8s update-ips sets swift using application credential id for swift - harbor" {
  _test_apply_swift_application_credential_id '.harbor.persistence.type'
}

@test "ck8s update-ips sets swift using application credential id for swift - thanos" {
  _test_apply_swift_application_credential_id '.thanos.objectStorage.type'
}

@test "ck8s update-ips sets swift using application credential id for swift - rclone sync bucket source type" {
  _test_apply_swift_application_credential_id '.objectStorage.sync.buckets.[0].sourceType'
}

@test "ck8s update-ips extract swift url using username" {
  yq.set sc .harbor.persistence.type '"swift"'

  _mock

  sops --set '["objectStorage"]["swift"]["username"] "swift-username"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["swift"]["password"] "swift-password"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  run ck8s update-ips both apply --enable swift

  assert_equal "$(mock_get_call_args "${mock_curl}" 1)" "$(cat "${BATS_TEST_DIRNAME}/resources/get-swift-url-username.out")"
  assert_equal "$(mock_get_call_args "${mock_curl}" 2)" '-i -s -X DELETE -H X-Auth-Token: 123456789 -H X-Subject-Token: 123456789 https://keystone.foo.dev-ck8s.com:5678/auth/tokens'
  assert_equal "$(mock_get_call_args "${mock_dig}" 2)" 'A +short swift.foo.dev-ck8s.com'
}

@test "ck8s update-ips extract swift url using application credential id" {
  yq.set sc .harbor.persistence.type '"swift"'

  _mock

  sops --set '["objectStorage"]["swift"]["applicationCredentialID"] "swift-application-credential-id"' "${CK8S_CONFIG_PATH}/secrets.yaml"
  sops --set '["objectStorage"]["swift"]["applicationCredentialSecret"] "swift-application-credential-secret"' "${CK8S_CONFIG_PATH}/secrets.yaml"

  run ck8s update-ips both apply --enable swift

  assert_equal "$(mock_get_call_args "${mock_curl}" 1)" "$(cat "${BATS_TEST_DIRNAME}/resources/get-swift-url-application-credentails.out")"
  assert_equal "$(mock_get_call_args "${mock_curl}" 2)" '-i -s -X DELETE -H X-Auth-Token: 123456789 -H X-Subject-Token: 123456789 https://keystone.foo.dev-ck8s.com:5678/auth/tokens'
  assert_equal "$(mock_get_call_args "${mock_dig}" 2)" 'A +short swift.foo.dev-ck8s.com'
}
