#!/usr/bin/env bash

gitversion.setup_mocks() {
  mock_git="$(mock_create)"
  export mock_git
  git() {
    # shellcheck disable=SC2317
    "${mock_git}" "${@}"
  }
  export -f git
}

gitversion.mock_static() {
  mock_set_output "${mock_git}" "${1}"
}

# from, to
gitversion.mock_upgrade() {
  mock_set_output "${mock_git}" "${1}"
  mock_set_output "${mock_git}" "${2}"
}
