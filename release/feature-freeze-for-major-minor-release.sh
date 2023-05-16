#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=release/common.sh
source "${here}/common.sh"

# log_info_no_newline "What version version to you want to create (like v1.2.0): "
if [ $# -lt 1 ]; then
  log_error "Usage: $0 vX.Y.0"
  exit 1
fi

full_version="${1}"
if [[ ! "${full_version}" =~ ^v[0-9]+.[0-9]+.0$ ]]; then
  log_error "ERROR: Version must be in the form vX.Y.0 (where X is major and Y is minor version). Got: ${full_version}"
  exit 1
fi
# shellcheck disable=SC2001
major_version=$(echo "${full_version}" | sed 's/v\([0-9]\+\)\.[0-9]\+\.0/\1/')
# shellcheck disable=SC2001
minor_version=$(echo "${full_version}" | sed 's/v[0-9]\+\.\([0-9]\+\)\.0/\1/')

if [[ ! "${major_version}" =~ ^[0-9]+$ ]]; then
  log_error "ERROR: Major version must be a number. Got: ${major_version}"
  exit 1
fi

if [[ ! "${minor_version}" =~ ^[0-9]+$ ]]; then
  log_error "ERROR: Minor version must be a number. Got: ${minor_version}"
  exit 1
fi

# Make sure we have latest info
git fetch origin

if git tag -l | grep -P "^v${major_version}.${minor_version}.0$" > /dev/null; then
  log_error "ERROR: tag v${major_version}.${minor_version}.0 already exists"
  exit 1
fi

current_commit_hash=$(git rev-parse HEAD)
# Gets current branch name or if detached you get the short hash of the commit
current_branch_or_hash=$(git symbolic-ref -q --short HEAD || git rev-parse --short HEAD)
if git symbolic-ref -q --short HEAD > /dev/null; then
  make_sure_branch_is_up_to_date "${current_branch_or_hash}"
  log_warning_no_newline "Your current git branch is ${current_branch_or_hash}. Do you want to base the release from this (this should probably be main)? (y/n): "
else
  log_warning_no_newline "Your currently on a detached commit ${current_branch_or_hash}. Do you want to base the release from this (this should probably be main)? (y/n): "
fi

read -r sure_to_release
if [[ ! "${sure_to_release}" =~ ^[yY]$ ]]; then
  exit 1
fi

log_info "Creating release branch for version ${major_version}.${minor_version}"

if git branch -a | grep -P "release-${major_version}\.${minor_version}$" > /dev/null; then
  log_warning "Release branch release-${major_version}.${minor_version} already exists"
  log_warning "This might happen if you needed to rerun this script"
  log_info_no_newline "Do you want to reuse that one? (y/n): "
  read -r reuse_existing_release_branch
  if [[ ! "${reuse_existing_release_branch}" =~ ^[yY]$ ]]; then
    exit 1
  fi
  git switch "release-${major_version}.${minor_version}"
  make_sure_branch_is_up_to_date "release-${major_version}.${minor_version}"
else
  git switch -c "release-${major_version}.${minor_version}"
  git push -u origin "release-${major_version}.${minor_version}"
fi

## Check if reset changelog commit exists
if ! reset_commit_found "${major_version}" "${minor_version}"; then
  git switch -c "reset-changelog-${major_version}.${minor_version}"
  "${here}/reset-changelog.sh" "v${major_version}.${minor_version}.0"

  for file in $(git diff "${current_commit_hash}" --name-only); do
    if [[ ! "${file}" =~ ^(CHANGELOG.md|WIP-CHANGELOG.md)$ ]]; then
      log_error "ERROR: Didn't expect file ${file} to have been committed, aborting"
      exit 1
    fi
  done

  git push -u origin "reset-changelog-${major_version}.${minor_version}"

  log_warning "Create PRs: https://github.com/${this_repo}/compare/main...reset-changelog-${major_version}.${minor_version}"
  log_warning "Create PRs: https://github.com/${this_repo}/compare/release-${major_version}.${minor_version}...reset-changelog-${major_version}.${minor_version}"
  log_warning "Get these PRs merged NOW!!"
else
  log_info "Seems like changelog reset is already done, skipping to create it"
fi


is_merged="n"
until [[ "${is_merged}" =~ ^[yY]$ ]]; do
  log_info_no_newline "Is reset changelog commit merged to both release-${major_version}.${minor_version} and main? (y/n): "
  read -r is_merged
done

git switch main
git pull
if ! reset_commit_found "${major_version}" "${minor_version}"; then
  log_error "Reset changelog doesn't seem to be in the last 10 commits in main"
  exit 1
fi

git switch "release-${major_version}.${minor_version}"
git pull

if ! reset_commit_found "${major_version}" "${minor_version}"; then
  log_error "Reset changelog doesn't seem to be in the last 10 commits in release-${major_version}.${minor_version}"
  exit 1
fi

git switch "release-${major_version}.${minor_version}"

if git branch -a | grep -P "QA-${major_version}\.${minor_version}$" > /dev/null; then
  log_warning "QA branch QA-${major_version}.${minor_version} already exists"
  log_warning "This might happened if you needed to rerun this script"
  log_info_no_newline "Do you want to reuse that one? (y/n): "
  read -r reuse_existing_release_branch
  if [[ ! "${reuse_existing_release_branch}" =~ ^[yY]$ ]]; then
    exit 1
  fi
  git switch "QA-${major_version}.${minor_version}"
  make_sure_branch_is_up_to_date "QA-${major_version}.${minor_version}"
else
  git switch -c "QA-${major_version}.${minor_version}"
  git push -u origin "QA-${major_version}.${minor_version}"
fi

log_info "Now you're on the QA branch, finish all QA stuff and put all fixes here."
log_info "All changes should be noted in the CHANGELOG.md directly"
log_info "When it's done run the create-major-minor-release.sh script to create the release"
