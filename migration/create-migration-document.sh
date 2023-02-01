#!/bin/bash

set -euo pipefail

usage() {
    echo "This script must have apps old and new major versions as arguments."
    echo "Usage: $0 [old_version] [new_version]"
    echo "Example: ./create-migration-document.sh v0.22 v0.23"
}
if [  $# -lt 2 ]; then
    usage
    exit 1
fi

here="$(dirname "$(readlink -f "$0")")"
export old_version="${1}"
export new_version="${2}"
folder_name="${here}/${old_version}.x-${new_version}.x"

echo "You are about to create the migration documentation for versions"
echo "  from: ${old_version}"
echo "  to:   ${new_version}"
echo -n "Are you sure you want to continue [y/N]: "
read -r reply
if [[ ! "${reply}" =~ ^[yY]$ ]]; then
  echo "Aborting..."
  exit 0
fi

if [ -d "${folder_name}" ]; then
    echo "- ${folder_name} directory exists"
else
    mkdir "${folder_name}"
    echo "- ${folder_name} directory created"
fi

if [ -f "${folder_name}/upgrade-apps.md" ]; then
    echo -n "- ${folder_name}/upgrade-apps.md exists. Do you want to replace it? (y/N): "
    read -r reply
    if [[ ${reply} =~ ^[yY]$ ]]; then
        envsubst < "${here}/template/upgrade-apps.md" > "${folder_name}/upgrade-apps.md"
        echo "- ${folder_name}/upgrade-apps.md replaced"
    fi
else
    envsubst < "${here}/template/upgrade-apps.md" > "${folder_name}/upgrade-apps.md"
    echo "- ${folder_name}/upgrade-apps.md created"
fi
