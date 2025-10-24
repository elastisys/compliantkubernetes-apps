#!/usr/bin/env bash

set -euo pipefail

function usage() {
  echo "Usage: ${0} [FLAGS] [VERSION]" >&2
  echo "Example: ${0} --require-evaluation 1.2.3" >&2
  echo "If omitted, VERSION defaults to 'latest'" >&2
  exit 1
}

full_version_raw=""
forward_args=()

# Parse flags to forward to the image and optional VERSION
while [[ ${#} -gt 0 ]]; do
  case "${1}" in
  -h | --help)
    usage
    ;;
  -*)
    forward_args+=("${1}")
    shift
    ;;
  *)
    if [[ -n "${full_version_raw}" ]]; then
      echo "Too many positional arguments." >&2
      usage
    fi
    full_version_raw="${1}"
    shift
    ;;
  esac
done

# Default to 'latest' if VERSION not provided
full_version_raw="${full_version_raw:-latest}"

# Accept X.Y.Z (preferred) or vX.Y.Z (tolerated), or 'latest'
full_version="${full_version_raw#v}"

# Compute version flag for sbom-generator
if [[ "${full_version}" == "latest" ]]; then
  version_arg="latest"
else
  version_arg="v${full_version}"
fi

# Resolve repository root relative to this script
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# Paths relative to repository root (use absolute for reliability)
SBOM_OUTPUT="${REPO_ROOT}/sbom/sbom.cdx.json"
CONFIG="${REPO_ROOT}/sbom/sbom.config.yaml"

# Use container wrapper for consistent docker/podman behavior
WRAPPER="${REPO_ROOT}/scripts/run-from-container.sh"
CONTAINER_IMAGE="ghcr.io/elastisys/sbom-generator:0.1"

if [[ ! -x "${WRAPPER}" ]]; then
  echo "Missing or non-executable ${WRAPPER}." >&2
  exit 1
fi
# Ensure a writable cache directory inside the repo
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
"${WRAPPER}" --env XDG_CACHE_HOME="${XDG_CACHE_HOME}" "${extra_env[@]}" \
  "${CONTAINER_IMAGE}" "${forward_args[@]}" generate \
  --config "${CONFIG}" \
  --output-path "${SBOM_OUTPUT}" \
  --version "${version_arg}" \
  --force

echo "Validating SBOM ${SBOM_OUTPUT} ..."
"${WRAPPER}" --env XDG_CACHE_HOME="${XDG_CACHE_HOME}" "${extra_env[@]}" \
  "${CONTAINER_IMAGE}" "${forward_args[@]}" validate "${SBOM_OUTPUT}" --config "${CONFIG}"

# Ensure file ends with a single newline to satisfy linters
if [[ -s "${SBOM_OUTPUT}" ]]; then
  # Append a newline only if the last byte is not a newline
  if [[ $(tail -c1 "${SBOM_OUTPUT}" | wc -l) -eq 0 ]]; then
    printf '\n' >>"${SBOM_OUTPUT}"
  fi
fi

echo "SBOM generated and validated: ${SBOM_OUTPUT}"
