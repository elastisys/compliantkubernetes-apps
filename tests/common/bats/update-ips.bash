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

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1" 1        # .networkPolicies.global.scApiserver.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.2 127.0.2.2 127.0.3.2" 2        # .networkPolicies.global.scApiserver.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.21 127.0.2.21 127.0.3.21" 3     # .networkPolicies.global.scApiserver.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.3 127.0.2.3 127.0.3.3" 4        # .networkPolicies.global.scApiserver.ips calico wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.7 127.0.2.7 127.0.3.7" 5        # .networkPolicies.global.scNodes.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.8 127.0.2.8 127.0.3.8" 6        # .networkPolicies.global.scNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.81 127.0.2.81 127.0.3.81" 7     # .networkPolicies.global.scNodes.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.9 127.0.2.9 127.0.3.9" 8        # .networkPolicies.global.scNodes.ips calico wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.4 127.0.2.4 127.0.3.4" 9        # .networkPolicies.global.wcApiserver.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.5 127.0.2.5 127.0.3.5" 10       # .networkPolicies.global.wcApiserver.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.51 127.0.2.51 127.0.3.51" 11    # .networkPolicies.global.wcApiserver.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.6 127.0.2.6 127.0.3.6" 12       # .networkPolicies.global.wcApiserver.ips calico wireguard
  mock_set_output "${mock_kubectl}" "127.0.1.10 127.0.2.10 127.0.3.10" 13    # .networkPolicies.global.wcNodes.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.11 127.0.2.11 127.0.3.11" 14    # .networkPolicies.global.wcNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.111 127.0.2.111 127.0.3.111" 15 # .networkPolicies.global.wcNodes.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.12 127.0.2.12 127.0.3.12" 16    # .networkPolicies.global.wcNodes.ips calico wireguard

}

update_ips.mock_minimal_v6() {
  mock_set_output "${mock_dig}" "127.0.0.1" 1              # .networkPolicies.global.objectStorage.ips
  mock_set_output "${mock_dig}" "127.0.0.2" 3              # .networkPolicies.global.scIngress.ips
  mock_set_output "${mock_dig}" "fd3e:fab4:5eda:b233::1" 4 # .networkPolicies.global.scIngress.ips
  mock_set_output "${mock_dig}" "127.0.0.3" 5              # .networkPolicies.global.wcIngress.ips
  mock_set_output "${mock_dig}" "fd3e:fab4:5eda:b233::2" 6 # .networkPolicies.global.wcIngress.ips

  mock_set_output "${mock_kubectl}" "127.0.1.1 127.0.2.1 127.0.3.1 fd3e:fab4:5eda:b233::3 fd3e:fab4:5eda:b233::4 fd3e:fab4:5eda:b233::5" 1           # .networkPolicies.global.scApiserver.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.2 127.0.2.2 127.0.3.2 fd3e:fab4:5eda:b233::6 fd3e:fab4:5eda:b233::7 fd3e:fab4:5eda:b233::8" 4           # .networkPolicies.global.scApiserver.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.21 127.0.2.21 127.0.3.21 fd3e:fab4:5eda:b233::9 fd3e:fab4:5eda:b233::10 fd3e:fab4:5eda:b233::11" 5      # .networkPolicies.global.scApiserver.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.7 127.0.2.7 127.0.3.7 fd3e:fab4:5eda:b233::61 fd3e:fab4:5eda:b233::71 fd3e:fab4:5eda:b233::81" 7        # .networkPolicies.global.scNodes.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.8 127.0.2.8 127.0.3.8 fd3e:fab4:5eda:b233::12 fd3e:fab4:5eda:b233::13 fd3e:fab4:5eda:b233::14" 10       # .networkPolicies.global.scNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.81 127.0.2.81 127.0.3.81 fd3e:fab4:5eda:b233::15 fd3e:fab4:5eda:b233::16 fd3e:fab4:5eda:b233::17" 11    # .networkPolicies.global.scNodes.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.4 127.0.2.4 127.0.3.4 fd3e:fab4:5eda:b233::62 fd3e:fab4:5eda:b233::72 fd3e:fab4:5eda:b233::82" 13       # .networkPolicies.global.wcApiserver.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.5 127.0.2.5 127.0.3.5 fd3e:fab4:5eda:b233::18 fd3e:fab4:5eda:b233::19 fd3e:fab4:5eda:b233::20" 16       # .networkPolicies.global.wcApiserver.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.51 127.0.2.51 127.0.3.51 fd3e:fab4:5eda:b233::21 fd3e:fab4:5eda:b233::22 fd3e:fab4:5eda:b233::23" 17    # .networkPolicies.global.wcApiserver.ips calico vxlan
  mock_set_output "${mock_kubectl}" "127.0.1.10 127.0.2.10 127.0.3.10 fd3e:fab4:5eda:b233::63 fd3e:fab4:5eda:b233::73 fd3e:fab4:5eda:b233::83" 19    # .networkPolicies.global.wcNodes.ips node internal
  mock_set_output "${mock_kubectl}" "127.0.1.11 127.0.2.11 127.0.3.11 fd3e:fab4:5eda:b233::24 fd3e:fab4:5eda:b233::25 fd3e:fab4:5eda:b233::26" 20    # .networkPolicies.global.wcNodes.ips calico ipip
  mock_set_output "${mock_kubectl}" "127.0.1.111 127.0.2.111 127.0.3.111 fd3e:fab4:5eda:b233::27 fd3e:fab4:5eda:b233::28 fd3e:fab4:5eda:b233::29" 21 # .networkPolicies.global.wcNodes.ips calico vxlan
}

update_ips.mock_maximal() {
  update_ips.mock_minimal

  # main swift

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
  # DELETE /auth/tokens
  mock_set_output "${mock_curl}" "" 2
  mock_set_output "${mock_dig}" "127.1.0.4" 4 # keystone endpoint
  mock_set_output "${mock_dig}" "127.1.0.5" 5 # swift endpoint

  # rclone sync s3

  mock_set_output "${mock_dig}" "127.1.0.6" 6 # s3 endpoint

  # rclone sync swift

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
  {"token":{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com"}]}]}}' 3
  # DELETE /auth/tokens
  mock_set_output "${mock_curl}" "" 4

  mock_set_output "${mock_dig}" "127.1.0.7" 7 # keystone endpoint
  mock_set_output "${mock_dig}" "127.1.0.8" 8 # swift endpoint

  # rclone secondary

  mock_set_output "${mock_dig}" "127.1.0.9" 9 # secondary endpoint
}

update_ips.mock_rclone_s3() {
  update_ips.mock_minimal

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # .networkPolicies.rclone.sync.objectStorage.ips
}

update_ips.mock_rclone_s3_and_swift() {
  update_ips.mock_rclone_s3

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
  {"token":{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com"}]}]}}' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens

  mock_set_output "${mock_dig}" "127.0.0.5" 5 # networkPolicies.rclone.sync.objectStorageSwift.ips keystone endpoint
  mock_set_output "${mock_dig}" "127.0.0.6" 6 # networkPolicies.rclone.sync.objectStorageSwift.ips swift endpoint
}

update_ips.mock_rclone_swift() {
  update_ips.mock_minimal

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
  {"token":{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com"}]}]}}' 1
  mock_set_output "${mock_curl}" "" 2 # DELETE /auth/tokens

  mock_set_output "${mock_dig}" "127.0.0.5" 4 # networkPolicies.rclone.sync.objectStorageSwift.ips keystone endpoint
  mock_set_output "${mock_dig}" "127.0.0.6" 5 # networkPolicies.rclone.sync.objectStorageSwift.ips swift endpoint
}

update_ips.mock_swift() {
  update_ips.mock_minimal

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

  mock_set_output "${mock_dig}" "127.0.0.4" 4 # keystone endpoint
  mock_set_output "${mock_dig}" "127.0.0.5" 5 # swift endpoint
}

# --- populate ---------------------------------------------------------------------------------------------------------

update_ips.populate_minimal() {
  yq.set common .networkPolicies.global.objectStorage.ips '["127.0.0.1/32"]'
  yq.set common .networkPolicies.global.objectStorage.ports '[1234]'

  yq.set common .networkPolicies.global.scIngress.ips '["127.0.0.2/32"]'
  yq.set common .networkPolicies.global.wcIngress.ips '["127.0.0.3/32"]'

  yq.set sc .networkPolicies.global.scApiserver.ips '["127.0.1.1/32", "127.0.1.2/32", "127.0.1.3/32", "127.0.1.21/32", "127.0.2.1/32", "127.0.2.2/32", "127.0.2.3/32", "127.0.2.21/32", "127.0.3.1/32", "127.0.3.2/32", "127.0.3.3/32", "127.0.3.21/32"]'
  yq.set sc .networkPolicies.global.scNodes.ips '["127.0.1.7/32", "127.0.1.8/32", "127.0.1.9/32", "127.0.1.81/32", "127.0.2.7/32", "127.0.2.8/32", "127.0.2.9/32", "127.0.2.81/32", "127.0.3.7/32", "127.0.3.8/32", "127.0.3.9/32", "127.0.3.81/32"]'

  yq.set wc .networkPolicies.global.wcApiserver.ips '["127.0.1.4/32", "127.0.1.5/32", "127.0.1.6/32", "127.0.1.51/32", "127.0.2.4/32", "127.0.2.5/32", "127.0.2.6/32", "127.0.2.51/32", "127.0.3.4/32", "127.0.3.5/32", "127.0.3.6/32", "127.0.3.51/32"]'
  yq.set wc .networkPolicies.global.wcNodes.ips '["127.0.1.10/32", "127.0.1.11/32", "127.0.1.12/32", "127.0.1.111/32", "127.0.2.10/32", "127.0.2.11/32", "127.0.2.12/32", "127.0.2.111/32", "127.0.3.10/32", "127.0.3.11/32", "127.0.3.12/32", "127.0.3.111/32"]'
}

update_ips.populate_maximal() {
  update_ips.populate_minimal

  yq.set sc .networkPolicies.global.objectStorageSwift.ips '["127.1.0.4/32", "127.1.0.5/32"]'
  yq.set sc .networkPolicies.global.objectStorageSwift.ports '[5678, 91011]'

  yq.set sc .networkPolicies.rclone.sync.objectStorage.ips '["127.1.0.6/32"]'
  yq.set sc .networkPolicies.rclone.sync.objectStorage.ports '[1234]'

  yq.set sc .networkPolicies.rclone.sync.objectStorageSwift.ips '["127.1.0.7/32", "127.1.0.8/32"]'
  yq.set sc .networkPolicies.rclone.sync.objectStorageSwift.ports '[443, 5678]'

  yq.set sc .networkPolicies.rclone.sync.secondaryUrl.ips '["127.1.0.9/32"]'
  yq.set sc .networkPolicies.rclone.sync.secondaryUrl.ports '[1234]'
}

# --- asserts ----------------------------------------------------------------------------------------------------------

update_ips.assert_none() {
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 0
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 0
}

update_ips.assert_minimal() {
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[127.0.0.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[1234]"

  assert_equal "$(yq.dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[127.0.0.2/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[127.0.0.3/32]"

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[127.0.1.1/32, 127.0.1.2/32, 127.0.1.3/32, 127.0.1.21/32, 127.0.2.1/32, 127.0.2.2/32, 127.0.2.3/32, 127.0.2.21/32, 127.0.3.1/32, 127.0.3.2/32, 127.0.3.3/32, 127.0.3.21/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.scNodes.ips | . style="flow"')" "[127.0.1.7/32, 127.0.1.8/32, 127.0.1.9/32, 127.0.1.81/32, 127.0.2.7/32, 127.0.2.8/32, 127.0.2.9/32, 127.0.2.81/32, 127.0.3.7/32, 127.0.3.8/32, 127.0.3.9/32, 127.0.3.81/32]"

  assert_equal "$(yq.dig wc '.networkPolicies.global.wcApiserver.ips | . style="flow"')" "[127.0.1.4/32, 127.0.1.5/32, 127.0.1.6/32, 127.0.1.51/32, 127.0.2.4/32, 127.0.2.5/32, 127.0.2.6/32, 127.0.2.51/32, 127.0.3.4/32, 127.0.3.5/32, 127.0.3.6/32, 127.0.3.51/32]"
  assert_equal "$(yq.dig wc '.networkPolicies.global.wcNodes.ips | . style="flow"')" "[127.0.1.10/32, 127.0.1.11/32, 127.0.1.12/32, 127.0.1.111/32, 127.0.2.10/32, 127.0.2.11/32, 127.0.2.12/32, 127.0.2.111/32, 127.0.3.10/32, 127.0.3.11/32, 127.0.3.12/32, 127.0.3.111/32]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 3
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
}

update_ips.assert_minimal_v6() {
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ips | . style="flow"')" "[127.0.0.1/32]"
  assert_equal "$(yq.dig common '.networkPolicies.global.objectStorage.ports | . style="flow"')" "[1234]"

  assert_equal "$(yq.dig common '.networkPolicies.global.scIngress.ips | . style="flow"')" "[127.0.0.2/32, 'fd3e:fab4:5eda:b233::1/128']"
  assert_equal "$(yq.dig common '.networkPolicies.global.wcIngress.ips | . style="flow"')" "[127.0.0.3/32, 'fd3e:fab4:5eda:b233::2/128']"

  assert_equal "$(yq.dig sc '.networkPolicies.global.scApiserver.ips | . style="flow"')" "[127.0.1.1/32, 127.0.1.2/32, 127.0.1.21/32, 127.0.2.1/32, 127.0.2.2/32, 127.0.2.21/32, 127.0.3.1/32, 127.0.3.2/32, 127.0.3.21/32, 'fd3e:fab4:5eda:b233::3/128', 'fd3e:fab4:5eda:b233::4/128', 'fd3e:fab4:5eda:b233::5/128', 'fd3e:fab4:5eda:b233::6/128', 'fd3e:fab4:5eda:b233::7/128', 'fd3e:fab4:5eda:b233::8/128', 'fd3e:fab4:5eda:b233::9/128', 'fd3e:fab4:5eda:b233::10/128', 'fd3e:fab4:5eda:b233::11/128']"
  assert_equal "$(yq.dig sc '.networkPolicies.global.scNodes.ips | . style="flow"')" "[127.0.1.7/32, 127.0.1.8/32, 127.0.1.81/32, 127.0.2.7/32, 127.0.2.8/32, 127.0.2.81/32, 127.0.3.7/32, 127.0.3.8/32, 127.0.3.81/32, 'fd3e:fab4:5eda:b233::12/128', 'fd3e:fab4:5eda:b233::13/128', 'fd3e:fab4:5eda:b233::14/128', 'fd3e:fab4:5eda:b233::15/128', 'fd3e:fab4:5eda:b233::16/128', 'fd3e:fab4:5eda:b233::17/128', 'fd3e:fab4:5eda:b233::61/128', 'fd3e:fab4:5eda:b233::71/128', 'fd3e:fab4:5eda:b233::81/128']"

  assert_equal "$(yq.dig wc '.networkPolicies.global.wcApiserver.ips | . style="flow"')" "[127.0.1.4/32, 127.0.1.5/32, 127.0.1.51/32, 127.0.2.4/32, 127.0.2.5/32, 127.0.2.51/32, 127.0.3.4/32, 127.0.3.5/32, 127.0.3.51/32, 'fd3e:fab4:5eda:b233::18/128', 'fd3e:fab4:5eda:b233::19/128', 'fd3e:fab4:5eda:b233::20/128', 'fd3e:fab4:5eda:b233::21/128', 'fd3e:fab4:5eda:b233::22/128', 'fd3e:fab4:5eda:b233::23/128', 'fd3e:fab4:5eda:b233::62/128', 'fd3e:fab4:5eda:b233::72/128', 'fd3e:fab4:5eda:b233::82/128']"
  assert_equal "$(yq.dig wc '.networkPolicies.global.wcNodes.ips | . style="flow"')" "[127.0.1.10/32, 127.0.1.11/32, 127.0.1.111/32, 127.0.2.10/32, 127.0.2.11/32, 127.0.2.111/32, 127.0.3.10/32, 127.0.3.11/32, 127.0.3.111/32, 'fd3e:fab4:5eda:b233::24/128', 'fd3e:fab4:5eda:b233::25/128', 'fd3e:fab4:5eda:b233::26/128', 'fd3e:fab4:5eda:b233::27/128', 'fd3e:fab4:5eda:b233::28/128', 'fd3e:fab4:5eda:b233::29/128', 'fd3e:fab4:5eda:b233::63/128', 'fd3e:fab4:5eda:b233::73/128', 'fd3e:fab4:5eda:b233::83/128']"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
  assert_equal "$(mock_get_call_num "${mock_dig}")" 6
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 24
}

update_ips.assert_swift() {
  assert_equal "$(yq.dig sc '.networkPolicies.global.objectStorageSwift.ips | . style="flow"')" "[127.0.0.4/32, 127.0.0.5/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.global.objectStorageSwift.ports | . style="flow"')" "[5678, 91011]"

  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
  assert_equal "$(mock_get_call_num "${mock_dig}")" 5
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
}

update_ips.assert_rclone_s3() {
  assert_equal "$(yq.dig sc '.networkPolicies.rclone.sync.objectStorage.ips | . style="flow"')" "[127.0.0.4/32]"
  assert_equal "$(yq.dig sc '.networkPolicies.rclone.sync.objectStorage.ports | . style="flow"')" "[1234]"

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorageSwift' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 4
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
  assert_equal "$(mock_get_call_num "${mock_curl}")" 0
}

update_ips.assert_rclone_s3_and_swift() {
  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorage | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.4/32]"
  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorage | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[1234]"

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.5/32, 127.0.0.6/32]"
  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 5678]"

  assert_equal "$(mock_get_call_num "${mock_dig}")" 6
  assert_equal "$(mock_get_call_num "${mock_kubectl}")" 16
  assert_equal "$(mock_get_call_num "${mock_curl}")" 2
}

update_ips.assert_rclone_swift() {
  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorageSwift | .ips style="flow" | .ips' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[127.0.0.5/32, 127.0.0.6/32]"
  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorageSwift | .ports style="flow" | .ports' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "[443, 5678]"

  assert_equal "$(yq4 '.networkPolicies.rclone.sync.objectStorage' "${CK8S_CONFIG_PATH}/sc-config.yaml")" "null"

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
  {"token":{"catalog":[{"type": "object-store", "name": "swift", "endpoints": [{"interface":"public", "region": "swift-region", "url": "https://swift.foo.dev-ck8s.com"}]}]}}' 1
  mock_set_output "${mock_curl}" "" 2         # DELETE /auth/tokens
  mock_set_output "${mock_dig}" "127.0.0.4" 4 # keystone endpoint
  mock_set_output "${mock_dig}" "127.0.0.5" 5 # swift endpoint
}
