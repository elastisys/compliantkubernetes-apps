#!/usr/bin/env bash

set -euo pipefail

# This script runs sbom-generator diff against the committed SBOM.
# The diff subcommand generates a fresh SBOM internally and compares
# it against the existing SBOM at --output-path. Exits non-zero on
# meaningful differences.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

WRAPPER="${REPO_ROOT}/scripts/run-from-container.sh"
IMAGE="ghcr.io/elastisys/sbom-generator:staging"
CONFIG="${REPO_ROOT}/sbom/sbom.config.yaml"
COMMITTED_SBOM="${REPO_ROOT}/sbom/sbom.cdx.json"

if [[ ! -x "${WRAPPER}" ]]; then
  echo "Missing or non-executable ${WRAPPER}." >&2
  exit 1
fi

# Ensure cache and output directories exist
XDG_CACHE_HOME="${REPO_ROOT}/.cache"
mkdir -p "${XDG_CACHE_HOME}"
mkdir -p "$(dirname "${COMMITTED_SBOM}")"

# Some container images don't have /tmp; set TMPDIR explicitly
export TMPDIR="${XDG_CACHE_HOME}"

echo "[sbom] Running diff against ${COMMITTED_SBOM} ..."
extra_env=()
if [[ -n "${CK8S_GITHUB_TOKEN:-}" ]]; then
  extra_env+=(--env CK8S_GITHUB_TOKEN)
fi
set +e
"${WRAPPER}" --env XDG_CACHE_HOME="${XDG_CACHE_HOME}" --env TMPDIR="${TMPDIR}" "${extra_env[@]}" \
  --env TERM="${TERM:-xterm-256color}" \
  "${IMAGE}" diff \
  --config "${CONFIG}" \
  --output-path "${COMMITTED_SBOM}"
status=$?
set -e

if [[ ${status} -eq 0 ]]; then
  echo "[sbom] OK: SBOM is up to date."
else
  echo "[sbom] Drift detected: SBOM has meaningful changes." >&2
  echo "[sbom] Hint: run 'sbom/generate.sh' to update SBOM." >&2
  echo "[sbom] If charts were updated, review and update evaluations in sbom/overrides.yaml." >&2
fi
exit ${status}
