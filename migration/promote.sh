#!/usr/bin/env bash

# Script to promote the upgrade and migration for releases.

set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "${HERE}")"

source "${ROOT}/scripts/common.sh"

usage() {
  echo -n "usage:
  - $0 $(esc.ylw "<release-series>") - promotes the upgrade and migration for the given release series in the form $(esc.ylw "vX.Y")
  "
}

main() {
  local series="${1:-}"

  [[ -n "${series}" ]] || log.fatal "missing required argument $(esc.ylw "<release-series>"), $(usage)"

  ver.parse next "${series}"

  local target_version="v${ver["next-major"]}.${ver["next-minor"]}"
  local target_migration="${ROOT}/migration/${target_version}"

  if [[ -d "${target_migration}" ]]; then
    if log.continue "migration $(esc.ylw "${target_version}") already exists, do you want to recreate it?"; then
      log.warn "removing migration $(esc.ylw "${target_version}")"
      rm -r "${target_migration}"
    else
      log.warn "skipping"
    fi
  fi

  if [[ ! -d "${target_migration}" ]]; then
    log.info "copying migration directory for $(esc.blu "${target_version}")"
    cp -Tr "${ROOT}/migration/main" "${target_migration}"
  fi

  # Find prev

  local -a directories
  readarray -t directories < <(find "${ROOT}/migration" -maxdepth 1 -type d -name 'v*')

  local directory
  for directory in "${directories[@]##"${ROOT}/migration/"}"; do
    ver.parse "${directory}" "${directory}"
  done

  local prev="prev"
  ver.parse "${prev}" "v0.0"

  for directory in "${directories[@]##"${ROOT}/migration/"}"; do
    if [[ "${directory}" == "${series}" ]]; then
      continue
    elif ver.gt "${directory}" "${prev}"; then
      prev="${directory}"
    fi
  done

  # replace references
  yq --inplace --front-matter process ".from =\"${prev}\"" "${target_migration}/README.md"
  yq --inplace --front-matter process ".to =\"${target_version}\"" "${target_migration}/README.md"
  yq --inplace --front-matter process ".from =\"${target_version}\"" "${ROOT}/migration/main/README.md"

  # Update header
  sed -i "s/# Main upgrade and migration/# ${target_version} upgrade and migration/" "${target_migration}/README.md"
  # Update preamble
  sed -i "/^<\!-- begin preamble --->$/,/^<\!--- end preamble --->$/c\\
> [\!important]\\
> This is the upgrade and migration process for Welkin Apps ${target_version}.\\
>\\
> Upgrade is supported from any patch version of the major or minor version stated in the \`from\` field above!" "${target_migration}/README.md"
  # Update changelog
  sed -i "s#\.\./\.\./changelog#../../changelog/${target_version}.md#" "${target_migration}/README.md"
  # Update fetch
  sed -i "s/Switch to the main branch and pull the latest changes/Fetch the latest changes and switch to the release tag/" "${target_migration}/README.md"
  sed -i "s/git switch main/git fetch/" "${target_migration}/README.md"
  sed -i "s/git pull/git switch -d ${target_version}.z/" "${target_migration}/README.md"

  # Prune

  while [[ "${#directories[*]}" -gt 5 ]]; do
    # Find last
    local last="${target_version}"
    ver.parse "${last}" "${target_version}"

    for directory in "${directories[@]##"${ROOT}/migration/"}"; do
      if [[ "${directory}" == "${series}" ]]; then
        continue
      elif ver.gt "${last}" "${directory}"; then
        last="${directory}"
      fi
    done

    log.info "pruning old migration $(esc.blu "${last}")"
    rm -r "${ROOT}/migration/${last}"

    local -a directories
    readarray -t directories < <(find "${ROOT}/migration" -maxdepth 1 -type d -name 'v*')
  done
}

main "${@}"
