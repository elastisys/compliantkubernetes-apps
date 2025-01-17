#!/bin/bash

# This script runs Helm commands against a Helm chart generated from a
# Crossplane Helm Release resource.
#
# It currently only supports grabbing values from .spec.forProvider.values.

set -euo pipefail

command="${1}"
release_name="${2}"
crossplane_release_contents="$(cat "${3}")"

helm_temporary_repo_name="welkin-crossplane-module-diff-${release_name}"

release_namespace=$(echo "${crossplane_release_contents}" | yq4 '.spec.forProvider.namespace')
chart_repository=$(echo "${crossplane_release_contents}" | yq4 '.spec.forProvider.chart.repository')
chart_name=$(echo "${crossplane_release_contents}" | yq4 '.spec.forProvider.chart.name')
chart_version=$(echo "${crossplane_release_contents}" | yq4 '.spec.forProvider.chart.version')
values="$(echo "${crossplane_release_contents}" | yq4 -o json '.spec.forProvider.values')"

helm repo add "${helm_temporary_repo_name}" "${chart_repository}" >/dev/null
trap 'helm repo remove "${helm_temporary_repo_name}" >/dev/null' EXIT

helm repo update >/dev/null

case "${command}" in
diff)
  echo "${values}" |
    helm diff -n "${release_namespace}" upgrade "${release_name}" "${helm_temporary_repo_name}/${chart_name}" \
      --version "${chart_version}" \
      --allow-unreleased \
      --reset-values \
      --values -
  ;;
template)
  echo "${values}" |
    helm -n "${release_namespace}" template "${release_name}" "${helm_temporary_repo_name}/${chart_name}" \
      --version "${chart_version}" \
      --values -
  ;;
*)
  echo "Invalid command: ${command}" >&2
  exit 1
  ;;
esac
