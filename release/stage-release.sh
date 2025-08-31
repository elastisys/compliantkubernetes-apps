#!/usr/bin/env bash

set -euo pipefail

if ! command -v releaser >/dev/null; then
  echo "releaser is not installed, install it by running: go install github.com/elastisys/releaser/cmd/releaser@latest" >&2
  echo "For more information see https://github.com/elastisys/releaser/#installation" >&2
  exit 1
fi

function missing_env_var() {
  echo "Error: Environment variable ${1} is not set." >&2
  exit 1
}

function usage() {
  echo "Usage: ${0} VERSION" >&2
  exit 1
}

[ ${#} -eq 1 ] || usage
[ -n "${CK8S_GITHUB_TOKEN:-}" ] || missing_env_var "CK8S_GITHUB_TOKEN"

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
[ "${patch}" != "0" ] && printf "\n#" >>"${changelog_path}"

releaser changelog compliantkubernetes-apps "${full_version}" >>"${changelog_path}"

git add "${changelog_path}"
git commit -m "Add changelog for release v${full_version}"

#
# Generate SBOM
#

SBOM_OUTPUT="docs/CycloneDX/sbom.cdx.json"
CONFIG="docs/CycloneDX/sbom.config.yaml"

if ! command -v sbom-generator >/dev/null; then
  echo "sbom-generator is not installed. Install it by running:" >&2
  echo "go install github.com/elastisys/sbom-generator/cmd/sbom-generator@latest" >&2
  echo "For more information see https://github.com/elastisys/sbom-generator/#installation" >&2
  echo "If script fails here, run the rest of the script separately when sbom-generator is installed."
  exit 1
fi

echo "Generating SBOM to ${SBOM_OUTPUT} ..."
GITHUB_TOKEN="${CK8S_GITHUB_TOKEN}" \
  sbom-generator generate \
  --config "${CONFIG}" \
  --output-path "${SBOM_OUTPUT}" \
  --version "v${full_version}" \
  --force

echo "Validating SBOM ${SBOM_OUTPUT} ..."
sbom-generator validate "${SBOM_OUTPUT}" --config "${CONFIG}"

echo "SBOM generated and validated: ${SBOM_OUTPUT}"
