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
