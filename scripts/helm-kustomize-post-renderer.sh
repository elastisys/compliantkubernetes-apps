#!/usr/bin/env bash

# This script is used to run kustomize as a Helm post-renderer.
#
# Example: helm diff --post-renderer ./helm-kustomize-post-renderer.sh --post-renderer-args /path/to/kustomize/directory
#
# Note that the kustomization.yaml should have an initial resource named
# "rendered-templates.yaml" which will include the initial output from Helm's
# template rendering which then can be patched further.
#
# Example:
#
# resources:
#   - rendered-templates.yaml
# patches:
#   - path: patch.yaml
#     target:
#       kind: Deployment
#       name: foo

set -euo pipefail

if [ "${#}" -ne "1" ]; then
  echo "Usage: ${0} KUSTOMIZE_DIR" >&2
  exit 1
fi

cat >"${1}/rendered-templates.yaml"

kubectl kustomize "${1}" && rm "${1}/rendered-templates.yaml"
