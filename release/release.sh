#!/bin/bash

set -euo pipefail

function usage() {
    echo "Usage: ${0} VERSION" >&2
    exit 1
}

[ ${#} -eq 1 ] || usage

new_version="${1}"

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

last_message=$(git log -1 --pretty=%B)
git commit --amend -m "Release v${new_version}" -m "${last_message}"

git tag "v${new_version}"
