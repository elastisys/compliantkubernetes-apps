#!/bin/bash

set -eu -o pipefail

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# shellcheck source=release/common.sh
source "${here}/common.sh"

current_branch=$(git symbolic-ref -q --short HEAD)
if [[ ! "${current_branch}" =~ ^release-[0-9]+\.[0-9]+$ ]]; then
  log_error "Error: Expected to be on release branch, e.g. release-1.2. Got: ${current_branch}"
  exit 1
fi

# shellcheck disable=SC2001
major_version=$(echo "${current_branch}" | sed 's/release-\([0-9]\+\)\.[0-9]\+/\1/')
# shellcheck disable=SC2001
minor_version=$(echo "${current_branch}" | sed 's/release-[0-9]\+\.\([0-9]\+\)/\1/')

# Make sure branch is up to date with upstream (might happen if someone missed to run pull after merging QA branch)
make_sure_branch_is_up_to_date "release-${major_version}.${minor_version}"

# Create the tag and push.
# This will start the github action to create the release.
tag="v${major_version}.${minor_version}.0"
log_warning_no_newline "Your about to create the release ${tag} are you sure? (y/n): "
read -r sure_to_release
if [[ ! "${sure_to_release}" =~ ^[yY]$ ]]; then
  exit 1
fi

git tag "${tag}"
git push --tags

if ! git log -1 --format=%s | grep -P "^Reset changelog for release ${tag}$" > /dev/null; then
  release_head_commit=$(git rev-parse --short HEAD)
  reset_commit=$(git log "-${commit_lookback}" --oneline | grep -P "Reset changelog for release ${tag}$" | awk '{print $1}')

  git switch main
  git pull

  git switch -c "patches-from-release-${major_version}.${minor_version}"
  git push -u origin "patches-from-release-${major_version}.${minor_version}"

  log_info "Please run these commands from top to bottom and fix any merge conflicts, then merge this to the main branch:"
  for commit in $(git log "${reset_commit}..${release_head_commit}" --format=%h); do
    echo "git cherry-pick ${commit}"
  done
fi
