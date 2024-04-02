#!/usr/bin/env bash

update_ips.setup_mocks() {
  mock_curl="$(mock_create)"
  export mock_curl
  curl() {
    # shellcheck disable=SC2317
    "${mock_curl}" "${@}"
  }
  export -f curl

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
}

update_ips.assert_mocks_none() {
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

# --- mocks ------------------------------------------------------------------------------------------------------------

update_ips.mock_minimal() {
  mock_set_output "${mock_dig}" "127.0.0.1" 1 # .networkPolicies.global.objectStorage.ips
  mock_set_output "${mock_dig}" "127.0.0.2" 2 # .networkPolicies.global.scIngress.ips
  mock_set_output "${mock_dig}" "127.0.0.3" 3 # .networkPolicies.global.wcIngress.ips

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1" 1 # .networkPolicies.global.scApiserver.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.2 127.0.2.2 127.0.3.2" 2 # .networkPolicies.global.scApiserver.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.2 127.0.2.2 127.0.3.2" 3 # .networkPolicies.global.scApiserver.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.3 127.0.2.3 127.0.3.3" 4 # .networkPolicies.global.scApiserver.ips calico wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.7 127.0.2.7 127.0.3.7" 5 # .networkPolicies.global.scNodes.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.8 127.0.2.8 127.0.3.8" 6 # .networkPolicies.global.scNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.8 127.0.2.8 127.0.3.8" 7 # .networkPolicies.global.scNodes.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.9 127.0.2.9 127.0.3.9" 8 # .networkPolicies.global.scNodes.ips calico wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.4 127.0.2.4 127.0.3.4" 9 # .networkPolicies.global.wcApiserver.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.5 127.0.2.5 127.0.3.5" 10 # .networkPolicies.global.wcApiserver.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.5 127.0.2.5 127.0.3.5" 11 # .networkPolicies.global.wcApiserver.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.6 127.0.2.6 127.0.3.6" 12 # .networkPolicies.global.wcApiserver.ips calico wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.10 127.0.2.10 127.0.3.10" 13 # .networkPolicies.global.wcNodes.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.11 127.0.2.11 127.0.3.11" 14 # .networkPolicies.global.wcNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.11 127.0.2.11 127.0.3.11" 15 # .networkPolicies.global.wcNodes.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.12 127.0.2.12 127.0.3.12" 16 # .networkPolicies.global.wcNodes.ips calico wireguard
}

update_ips.mock_maximal() {
  update_ips.mock_minimal

  # main swift

  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com:91011"}]}]}]' 1
  # DELETE /auth/tokens
  mock_set_output "${mock_curl}" "" 2
  mock_set_output "${mock_dig}" "127.1.0.4" 4 # keystone endpoint
  mock_set_output "${mock_dig}" "127.1.0.5" 5 # swift endpoint

  # rclone sync s3

  mock_set_output "${mock_dig}" "127.1.0.6" 6 # s3 endpoint

  # rclone sync swift

  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com"}]}]}]' 3
  # DELETE /auth/tokens
  mock_set_output "${mock_curl}" "" 4

  mock_set_output "${mock_dig}" "127.1.0.7" 7 # keystone endpoint
  mock_set_output "${mock_dig}" "127.1.0.8" 8 # swift endpoint

  # rclone secondary

  mock_set_output "${mock_dig}" "127.1.0.9" 9 # secondary endpoint
}

update_ips.mock_rclone_s3() {
  update_ips.mock_minimal

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # .networkPolicies.rcloneSync.destinationObjectStorageS3.ips
}

update_ips.mock_rclone_s3_and_swift() {
  update_ips.mock_rclone_s3

  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com"}]}]}]' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens

  mock_set_output "${mock_dig}" "127.0.0.5" 5 # networkPolicies.rcloneSync.destinationObjectStorageSwift.ips keystone endpoint
  mock_set_output "${mock_dig}" "127.0.0.6" 6 # networkPolicies.rcloneSync.destinationObjectStorageSwift.ips swift endpoint
}

update_ips.mock_rclone_swift() {
  update_ips.mock_minimal

  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com"}]}]}]' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens

  mock_set_output "${mock_dig}" "127.0.0.5" 4 # networkPolicies.rcloneSync.destinationObjectStorageSwift.ips keystone endpoint
  mock_set_output "${mock_dig}" "127.0.0.6" 5 # networkPolicies.rcloneSync.destinationObjectStorageSwift.ips swift endpoint
}

update_ips.mock_swift() {
  update_ips.mock_minimal

  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com:91011"}]}]}]' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # keystone endpoint
  mock_set_output "${mock_dig}" "127.0.0.5" 5 # swift endpoint
}

# --- populate ---------------------------------------------------------------------------------------------------------

update_ips.populate_minimal() {
  yq_set common .networkPolicies.global.objectStorage.ips '["127.0.0.1/32"]'
  yq_set common .networkPolicies.global.objectStorage.ports '[1234]'

  yq_set common .networkPolicies.global.scIngress.ips '["127.0.0.2/32"]'
  yq_set common .networkPolicies.global.wcIngress.ips '["127.0.0.3/32"]'

  yq_set sc .networkPolicies.global.scApiserver.ips '["127.0.1.1/32", "127.0.1.2/32", "127.0.1.3/32", "127.0.2.1/32", "127.0.2.2/32", "127.0.2.3/32", "127.0.3.1/32", "127.0.3.2/32", "127.0.3.3/32"]'
  yq_set sc .networkPolicies.global.scNodes.ips '["127.0.1.7/32", "127.0.1.8/32", "127.0.1.9/32", "127.0.2.7/32", "127.0.2.8/32", "127.0.2.9/32", "127.0.3.7/32", "127.0.3.8/32", "127.0.3.9/32"]'

  yq_set wc .networkPolicies.global.wcApiserver.ips '["127.0.1.4/32", "127.0.1.5/32", "127.0.1.6/32", "127.0.2.4/32", "127.0.2.5/32", "127.0.2.6/32", "127.0.3.4/32", "127.0.3.5/32", "127.0.3.6/32"]'
  yq_set wc .networkPolicies.global.wcNodes.ips '["127.0.1.10/32", "127.0.1.11/32", "127.0.1.12/32", "127.0.2.10/32", "127.0.2.11/32", "127.0.2.12/32", "127.0.3.10/32", "127.0.3.11/32", "127.0.3.12/32"]'
}

update_ips.populate_maximal() {
  update_ips.populate_minimal

  yq_set sc .networkPolicies.global.objectStorageSwift.ips '["127.1.0.4/32", "127.1.0.5/32"]'
  yq_set sc .networkPolicies.global.objectStorageSwift.ports '[5678, 91011]'

  yq_set sc .networkPolicies.rcloneSync.destinationObjectStorageS3.ips '["127.1.0.6/32"]'
  yq_set sc .networkPolicies.rcloneSync.destinationObjectStorageS3.ports '[1234]'

  yq_set sc .networkPolicies.rcloneSync.destinationObjectStorageSwift.ips '["127.1.0.7/32", "127.1.0.8/32"]'
  yq_set sc .networkPolicies.rcloneSync.destinationObjectStorageSwift.ports '[443, 5678]'

  yq_set sc .networkPolicies.rcloneSync.secondaryUrl.ips '["127.1.0.9/32"]'
  yq_set sc .networkPolicies.rcloneSync.secondaryUrl.ports '[1234]'
}

# --- asserts ----------------------------------------------------------------------------------------------------------

update_ips.assert_none() {
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

update_ips.assert_minimal() {
  assert_equal "$(yq_dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[127.0.0.1/32]"
  assert_equal "$(yq_dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[1234]"

  assert_equal "$(yq_dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[127.0.0.2/32]"
  assert_equal "$(yq_dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[127.0.0.3/32]"

  assert_equal "$(yq_dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[127.0.1.1/32, 127.0.1.2/32, 127.0.1.3/32, 127.0.2.1/32, 127.0.2.2/32, 127.0.2.3/32, 127.0.3.1/32, 127.0.3.2/32, 127.0.3.3/32]"
  assert_equal "$(yq_dig sc '.networkPolicies.global.scNodes.ips | . style="flow"')" "[127.0.1.7/32, 127.0.1.8/32, 127.0.1.9/32, 127.0.2.7/32, 127.0.2.8/32, 127.0.2.9/32, 127.0.3.7/32, 127.0.3.8/32, 127.0.3.9/32]"

  assert_equal "$(yq_dig wc '.networkPolicies.global.wcApiserver.ips | . style="flow"')" "[127.0.1.4/32, 127.0.1.5/32, 127.0.1.6/32, 127.0.2.4/32, 127.0.2.5/32, 127.0.2.6/32, 127.0.3.4/32, 127.0.3.5/32, 127.0.3.6/32]"
  assert_equal "$(yq_dig wc '.networkPolicies.global.wcNodes.ips | . style="flow"')" "[127.0.1.10/32, 127.0.1.11/32, 127.0.1.12/32, 127.0.2.10/32, 127.0.2.11/32, 127.0.2.12/32, 127.0.3.10/32, 127.0.3.11/32, 127.0.3.12/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
}

update_ips.assert_swift() {
  assert_equal "$(yq_dig sc '.networkPolicies.global.objectStorageSwift.ips | . style="flow"')" "[127.0.0.4/32, 127.0.0.5/32]"
  assert_equal "$(yq_dig sc '.networkPolicies.global.objectStorageSwift.ports | . style="flow"')" "[5678, 91011]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
  assert_equal "$(mock_get_call_num "${mock_dig}")" 5
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
}

update_ips.assert_rclone_s3() {
  assert_equal "$(yq_dig sc '.networkPolicies.rcloneSync.destinationObjectStorageS3.ips | . style="flow"')" "[127.0.0.4/32]"
  assert_equal "$(yq_dig sc '.networkPolicies.rcloneSync.destinationObjectStorageS3.ports | . style="flow"')" "[1234]"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 4
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

update_ips.assert_rclone_s3_and_swift() {
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3 | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[1234]"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.5/32, 127.0.0.6/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 5678]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 6
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

update_ips.assert_rclone_swift() {
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.5/32, 127.0.0.6/32]"
  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 5678]"

  assert_equal "$(yq4 '.networkPolicies.rcloneSync.destinationObjectStorageS3' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  # GET /auth/tokens
  mock_set_output "${mock_curl}" '\n\n\n\n\n\n\n\n\n\n\n\n\n\n[{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com"}]}]}]' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens
  mock_set_output "${mock_dig}" "127.0.0.4" 4 # keystone endpoint
  mock_set_output "${mock_dig}" "127.0.0.5" 5 # swift endpoint
}
