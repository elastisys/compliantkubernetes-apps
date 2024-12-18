#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "This script must have apps old and new major versions as arguments."
  echo "Usage: $0 [old_version] [new_version]"
  echo "Example: ./create-migration-document.sh v0.22 v0.23"
}
if [ $# -lt 2 ]; then
  usage
  exit 1
fi

here="$(dirname "$(readlink -f "$0")")"
export old_version="${1}"
export new_version="${2}"
folder_name="${here}/${new_version}"

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

if [ -f "${folder_name}/README.md" ]; then
  echo -n "- ${folder_name}/README.md exists. Do you want to replace it? (y/N): "
  read -r reply
  if [[ ${reply} =~ ^[yY]$ ]]; then
    # shellcheck disable=SC2016
    envsubst '$new_version$old_version' <"${here}/template/README.md" >"${folder_name}/README.md"
    echo "- ${folder_name}/README.md replaced"
  fi
else
  # shellcheck disable=SC2016
  envsubst '$new_version$old_version' <"${here}/template/README.md" >"${folder_name}/README.md"
  echo "- ${folder_name}/README.md created"
fi

cp -r "${here}/template/apply" "${folder_name}/"
cp -r "${here}/template/prepare" "${folder_name}/"
