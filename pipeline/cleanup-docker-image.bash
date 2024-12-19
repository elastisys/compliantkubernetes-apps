#!/usr/bin/env bash

# Remove Docker image GITHUB_SHA tag created by pipeline from Docker Hub
set -eu -o pipefail

if [ -z ${GITHUB_SHA+x} ]; then
  echo "GITHUB_SHA not set, skipping Docker tag deletion." >&2
else
  : "${GITHUB_ACTOR:?Missing GITHUB_ACTOR}"
  : "${GITHUB_TOKEN:?Missing GITHUB_TOKEN}"

  # At the moment you need to know the version id to delete a container version.
  # To fetch it you need to list all versions and fetch the ID of the one with the correct tag.
  # One entry in the list of versions looks something like this:
  #   {
  #     "id": 123456,
  #     ...
  #     "metadata": {
  #       "container": {
  #         "tags": [
  #           "${GITHUB_SHA}"
  #         ]
  #       }
  #     }
  #   }
  # So to fetch the id we need to match to any entry that has the commit hash and fetch that id
  # The jq filter here is not foolproof and can return multiple versions if there's more than one version ID with the same tag.
  VERSION_ID=$(curl -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/orgs/elastisys/packages/container/compliantkubernetes-apps-pipeline/versions |
    jq '.[] | select(.metadata.container.tags | any(. == "'"${GITHUB_SHA}"'")).id')

  echo "Deleting Github package tag: ${GITHUB_SHA} (Version ID: ${VERSION_ID})" >&2

  if [[ ! "${VERSION_ID}" =~ ^[0-9]+$ ]]; then
    echo "Version ID not correctly formatted" >&2
    exit 1
  fi

  curl -s \
    -X DELETE \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/orgs/elastisys/packages/container/compliantkubernetes-apps-pipeline/versions/${VERSION_ID}"
fi
