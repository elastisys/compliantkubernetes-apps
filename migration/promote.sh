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

create() {
  local target_version="${1:-}" target_migration="${2:-}"

  # check if the target migration already exists
  if [[ -d "${target_migration}" ]]; then
    log.fatal "migration $(esc.red "${target_version}") already exists, if the creation of it is incomplete remove it and restore the main migration from git before retrying!"
  fi

  log.info "copying migration directory for $(esc.blu "${target_version}")"
  cp -Tr "${ROOT}/migration/main" "${target_migration}"

  local -a snippets
  local snippet

  # rename all-versions in next
  readarray -t snippets < <(find "${target_migration}" -maxdepth 2 -type f -name '*-all-versions.sh')
  for snippet in "${snippets[@]}"; do
    mv "${snippet}" "${snippet/%"-all-versions.sh"/".sh"}"
  done

  # rename one-version in next
  readarray -t snippets < <(find "${target_migration}" -maxdepth 2 -type f -name '*-one-version.sh')
  for snippet in "${snippets[@]}"; do
    mv "${snippet}" "${snippet/%"-one-version.sh"/".sh"}"
  done

  # prune one-version in main
  readarray -t snippets < <(find "${ROOT}/migration/main" -maxdepth 2 -type f -name '*-one-version.sh')
  for snippet in "${snippets[@]}"; do
    rm "${snippet}"
  done

  # find current migration directories
  local -a directories
  readarray -t directories < <(find "${ROOT}/migration" -maxdepth 1 -type d -name 'v*')

  local directory
  for directory in "${directories[@]##"${ROOT}/migration/"}"; do
    ver.parse "${directory}" "${directory}"
  done

  # the previous - the greatest excluding the current
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

  # update header
  sed -i "s/# Main upgrade and migration/# ${target_version} upgrade and migration/" "${target_migration}/README.md"
  # update preamble
  sed -i "/^<\!-- begin preamble --->$/,/^<\!--- end preamble --->$/c\\
> [\!important]\\
> This is the upgrade and migration process for Welkin Apps ${target_version}.\\
>\\
> Upgrade is supported from any patch version of the major or minor version stated in the \`from\` field above!" "${target_migration}/README.md"
  # update changelog
  sed -i "s#\.\./\.\./changelog#../../changelog/${target_version}.md#" "${target_migration}/README.md"
  # update fetch
  sed -i "s/Switch to the main branch and pull the latest changes/Fetch the latest changes and switch to the release tag/" "${target_migration}/README.md"
  sed -i "s/git switch main/git fetch/" "${target_migration}/README.md"
  sed -i "s/git pull/git switch -d ${target_version}.z/" "${target_migration}/README.md"
}

prune() {
  local target_version="${1:-}"

  # find current migration directories
  local -a directories
  readarray -t directories < <(find "${ROOT}/migration" -maxdepth 1 -type d -name 'v*')

  # until we have five migrations left
  while [[ "${#directories[*]}" -gt 5 ]]; do
    # the last - the least including the current
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

    readarray -t directories < <(find "${ROOT}/migration" -maxdepth 1 -type d -name 'v*')
  done
}

main() {
  local series="${1:-}"

  [[ -n "${series}" ]] || log.fatal "missing required argument $(esc.ylw "<release-series>"), $(usage)"

  ver.parse next "${series}"

  local version="v${ver["next-major"]}.${ver["next-minor"]}"
  local migration="${ROOT}/migration/${version}"

  create "${version}" "${migration}"

  prune "${version}"
}

main "${@}"
