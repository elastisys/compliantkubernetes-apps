#!/bin/bash

set -eu -o pipefail

commit_lookback=10
# shellcheck disable=SC2034
this_repo="elastisys/compliantkubernetes-apps"

make_sure_branch_is_up_to_date() {
  git fetch origin
  if [[ "$(git rev-parse "${1}")" != "$(git rev-parse "origin/${1}")" ]]; then
    log_error "ERROR: Your branch isn't up to date with upstream, please run 'git pull' and try again"
    exit 1
  fi
}

reset_commit_found() {
  if git log "-${commit_lookback}" --format=%s | grep -P "^Reset changelog for release v${1}.${2}.0$" > /dev/null; then
    return 0
  else
    return 1
  fi
}

log_info_no_newline() {
  echo -e -n "[\e[34mck8s\e[0m] ${*}" 1>&2
}

log_info() {
  log_info_no_newline "${*}\n"
}

log_warning_no_newline() {
    echo -e -n "[\e[33mck8s\e[0m] ${*}" 1>&2
}

log_warning() {
    log_warning_no_newline "${*}\n"
}

log_error_no_newline() {
    echo -e -n "[\e[31mck8s\e[0m] ${*}" 1>&2
}

log_error() {
    log_error_no_newline "${*}\n"
}
