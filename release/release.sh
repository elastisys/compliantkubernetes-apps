#!/bin/bash

set -euo pipefail

function usage() {
    echo "Usage: ${0} VERSION" >&2
    exit 1
}

[ ${#} -eq 1 ] || usage

new_version="${1}"

here="$(dirname "$(readlink -f "$0")")"
root="${here}/.."
changelog="${root}/CHANGELOG.md"
wip_changelog="${root}/WIP-CHANGELOG.md"

function file_exists() {
    if [ ! -f "${1}" ]; then
        echo "ERROR: ${1} does not exist" >&2
        exit 1
    fi
}
file_exists "${changelog}"
file_exists "${wip_changelog}"

# Regex found from https://gist.github.com/rverst/1f0b97da3cbeb7d93f4986df6e8e5695
function check_version() {
    if [[ ! $1 =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$ ]]; then
        echo "${1} is not a valid version" >&2
        exit 1
    fi

    if git rev-parse "v${1}" >/dev/null 2>&1; then
        echo "v${1} tag already exists" >&2
        exit 1
    fi
}

check_version "${new_version}"

short_version="${new_version//./}"
DATE=$(date +'%Y-%m-%d')

### Generating new changelog by combining CHANGELOG.md and WIP-CHANGELOG.md ###
echo "generating new changelog"

# Split Changelog and Table of contents(TOC) into seperate files
sed -n '/<!-- BEGIN TOC -->/,/<!-- END TOC -->/{ /<!--/d; p }' "${changelog}" > temp-toc.md
sed '1,/^<!-- END TOC -->$/d' "${changelog}" > temp-cl.md

# Adding version to changelog
echo -e "## v${new_version} - ${DATE}\n" | cat - "${wip_changelog}" temp-cl.md > temp-cl2.md
# Adding link to TOC
echo -e "- [v${new_version}](#v${short_version}---${DATE})" | cat - temp-toc.md > temp-toc2.md
echo -e "<!-- END TOC -->" >> temp-toc2.md
echo -e "<!-- BEGIN TOC -->" | cat - temp-toc2.md > temp-toc.md
echo -e "\n-------------------------------------------------" >> temp-toc.md
# Creating new changelog
echo -e "# Compliant Kubernetes changelog" > "${changelog}"
cat temp-toc.md temp-cl2.md >> "${changelog}"
rm temp*
# Clearing WIP-CHANGELOG.md
true > "${wip_changelog}"

git add "${changelog}" "${wip_changelog}"
git commit -m "Release v${new_version}"
git tag "v${new_version}"
