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

release_namespace=$(yq4 '.spec.forProvider.namespace' <<<"${crossplane_release_contents}")
chart_repository=$(yq4 '.spec.forProvider.chart.repository' <<<"${crossplane_release_contents}")
chart_name=$(yq4 '.spec.forProvider.chart.name' <<<"${crossplane_release_contents}")
chart_version=$(yq4 '.spec.forProvider.chart.version' <<<"${crossplane_release_contents}")
values="$(yq4 -o json '.spec.forProvider.values' <<<"${crossplane_release_contents}")"

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
