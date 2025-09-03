#!/usr/bin/env bash

set -euo pipefail

function usage() {
  echo "Usage: ${0} [VERSION]" >&2
  echo "Example: ${0} 1.2.3" >&2
  echo "If omitted, VERSION defaults to 'latest'" >&2
  exit 1
}

# Accept zero or one argument. Default to 'latest'.
if [[ ${#} -gt 1 ]]; then
  usage
fi

if [[ ${#} -eq 1 ]]; then
  full_version_raw="${1}"
else
  full_version_raw="latest"
fi

# Accept X.Y.Z (preferred) or vX.Y.Z (tolerated), or 'latest'
full_version="${full_version_raw#v}"

# Compute version flag for sbom-generator
if [[ "${full_version}" == "latest" ]]; then
  version_arg="latest"
else
  version_arg="v${full_version}"
fi

# Paths relative to repository root
SBOM_OUTPUT="docs/CycloneDX/sbom.cdx.json"
CONFIG="docs/CycloneDX/sbom.config.yaml"

# Use container wrapper for consistent docker/podman behavior
WRAPPER="scripts/run-from-container.sh"
CONTAINER_IMAGE="ghcr.io/elastisys/sbom-generator:latest"

if [[ ! -x "${WRAPPER}" ]]; then
  echo "Missing or non-executable ${WRAPPER}." >&2
  exit 1
fi
# Ensure a writable cache directory inside the repo
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
XDG_CACHE_HOME="${REPO_ROOT}/.cache"
mkdir -p "${XDG_CACHE_HOME}"
# Ensure output directory exists
mkdir -p "$(dirname "${SBOM_OUTPUT}")"

echo "Generating SBOM to ${SBOM_OUTPUT} ..."
# Forward optional GitHub token to avoid rate limits
extra_env=()
if [[ -n "${CK8S_GITHUB_TOKEN:-}" ]]; then
  extra_env+=(--env CK8S_GITHUB_TOKEN)
fi
"${WRAPPER}" --env XDG_CACHE_HOME="${XDG_CACHE_HOME}" ${extra_env[@]:-} \
  "${CONTAINER_IMAGE}" generate \
  --config "${CONFIG}" \
  --output-path "${SBOM_OUTPUT}" \
  --version "${version_arg}" \
  --force

echo "Validating SBOM ${SBOM_OUTPUT} ..."
"${WRAPPER}" --env XDG_CACHE_HOME="${XDG_CACHE_HOME}" ${extra_env[@]:-} \
  "${CONTAINER_IMAGE}" validate "${SBOM_OUTPUT}" --config "${CONFIG}"

# Ensure file ends with a single newline to satisfy linters
if [[ -s "${SBOM_OUTPUT}" ]]; then
  # Append a newline only if the last byte is not a newline
  if [[ $(tail -c1 "${SBOM_OUTPUT}" | wc -l) -eq 0 ]]; then
    printf '\n' >>"${SBOM_OUTPUT}"
  fi
fi

echo "SBOM generated and validated: ${SBOM_OUTPUT}"
