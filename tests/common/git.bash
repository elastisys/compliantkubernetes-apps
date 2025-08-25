#!/usr/bin/env bash

# Git-related helpers

git.is_tracked() {
  local path="$1"
  local work_tree
  work_tree="$(git.parent_dir "${path}")"

  if git -C "${work_tree}" ls-files --error-unmatch "${path}" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

git.is_modified() {
  local path="$1"
  local work_tree
  work_tree="$(git.parent_dir "${path}")"

  if ! git.is_tracked "${path}" || (git -C "${work_tree}" diff --quiet "${path}" && git -C "${work_tree}" diff --quiet --cached "${path}"); then
    return 1
  else
    return 0
  fi
}

git.parent_dir() {
  local -r path="$(readlink -f "$1")"
  if [[ -f "$path" ]]; then
    dirname "${path}"
  else
    echo "${path}"
  fi
}
