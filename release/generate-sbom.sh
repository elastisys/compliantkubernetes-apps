#!/usr/bin/env bash

set -euo pipefail

function missing_env_var() {
  echo "Error: Environment variable ${1} is not set." >&2
  exit 1
}

function usage() {
  echo "Usage: ${0} X.Y.Z" >&2
  echo "Example: ${0} 1.2.3" >&2
  exit 1
}

[ ${#} -eq 1 ] || usage

# Accept X.Y.Z (preferred) or vX.Y.Z (tolerated)
full_version_raw="${1}"
full_version="${full_version_raw#v}"

# Paths relative to repository root
SBOM_OUTPUT="docs/CycloneDX/sbom.cdx.json"
CONFIG="docs/CycloneDX/sbom.config.yaml"

if ! command -v sbom-generator >/dev/null; then
  echo "sbom-generator is not installed. Install it by running:" >&2
  echo "go install github.com/elastisys/sbom-generator/cmd/sbom-generator@latest" >&2
  echo "For more information see https://github.com/elastisys/sbom-generator/#installation" >&2
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
