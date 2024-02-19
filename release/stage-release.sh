#!/usr/bin/env bash

set -euo pipefail

if ! command -v releaser >/dev/null; then
    echo "releaser is not installed, install it by running: go install github.com/elastisys/releaser/cmd/releaser@latest" >&2
    echo "For more information see https://github.com/elastisys/releaser/#installation" >&2
    exit 1
fi

function usage() {
    echo "Usage: ${0} VERSION" >&2
    exit 1
}

[ ${#} -eq 1 ] || usage

full_version="${1}"
series="$(echo "${full_version}" | cut -d '.' -f 1,2)"
patch="$(echo "${full_version}" | cut -d '.' -f 3)"

#
# Create staging branch
#

git switch "release-${series}"
git pull
git switch -c "staging-${full_version}"

#
# Cherry pick commits
#

for sha in ${CK8S_GIT_CHERRY_PICK:-}; do
    git cherry-pick "${sha}"
done

#
# Generate changelog
#

here="$(dirname "$(readlink -f "$0")")"
changelog_dir="${here}/../changelog"
changelog_path="${changelog_dir}/${series}.md"

mkdir -p "${changelog_dir}"

# If this is a patch release, add an extra newline before appending the patch
# notes. Also add an extra hashtag to please the markdownlint rule:
# MD025 Multiple top level headers in the same document
# TODO: Find a nicer way to do this.
[ "${patch}" != "0" ] && printf "\n#" >> "${changelog_path}"

releaser changelog compliantkubernetes-apps "${full_version}" >> "${changelog_path}"

git add "${changelog_path}"
git commit -m "Add changelog for release v${full_version}"
