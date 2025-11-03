#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

module_acceptance() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: module_acceptance <sc|wc> <module_selector> [<helm-post-renderer-kustomization-dir>]"
  fi

  local helmfile_list_result
  local helmfile_list_count
  local new_release_name
  local old_release_name
  local namespace
  local crossplane_release
  local crossplane_release_external_name
  local chart_repository
  local chart_name
  local chart_version
  local values
  local helm_diff_args

  helmfile_list_result="$(helmfile_list "${1}" "${2}")"

  helmfile_list_count="$(jq -r 'length' <<<"${helmfile_list_result}")"

  if [ "${helmfile_list_count}" -ne "1" ]; then
    log_fatal "Expected helmfile list -l ${2} to return 1 result, actual number: ${helmfile_list_count}"
  fi

  new_release_name="$(jq -r '.[0].name' <<<"${helmfile_list_result}")"
  old_release_name="${new_release_name#"module-"}"
  namespace="$(jq -r '.[0].namespace' <<<"${helmfile_list_result}")"

  log_info "Running ${new_release_name} acceptance test by comparing it with existing Helm Release ${old_release_name} in cluster ${1}"

  crossplane_release="$(_crossplane_render "${1}" "${new_release_name}" | yq 'select(.kind == "Release")')"

  crossplane_release_external_name=$(yq '.metadata.annotations["crossplane.io/external-name"]' <<<"${crossplane_release}")
  if [ "${crossplane_release_external_name}" != "${old_release_name}" ]; then
    log_error "Annotation 'crossplane.io/external-name' in Release in Module does not match existing Helm Release name"
    log_error "Expected: ${old_release_name}"
    log_error "Actual: ${crossplane_release_external_name}"
    log_fatal "DO NOT UPGRADE"
  fi

  if [ "$(_crossplane_xr "${1}" "${new_release_name}" | yq 'select(.apiVersion == "module.elastisys.com/v1alpha1").metadata.namespace')" != "null" ]; then
    log_fatal "The XR namespace is set, it should not be set. The namespace should be decided by Helmfile instead."
  fi
  if [ "$(yq '.metadata.namespace' <<<"${crossplane_release}")" != "null" ]; then
    log_fatal "Release .metadata.namespace is set, it should not be set. The namespace should be decided by where the Module is installed."
  fi
  if [ "$(yq '.spec.forProvider.namespace' <<<"${crossplane_release}")" != "null" ]; then
    log_fatal "Release .spec.forProvider.namespace is set, it should not be set. The namespace should be decided by where the Module is installed."
  fi

  chart_repository=$(yq '.spec.forProvider.chart.repository' <<<"${crossplane_release}")
  chart_name=$(yq '.spec.forProvider.chart.name' <<<"${crossplane_release}")
  chart_version=$(yq '.spec.forProvider.chart.version' <<<"${crossplane_release}")
  values="$(yq -o json '.spec.forProvider.values' <<<"${crossplane_release}")"

  helm_diff_args=(
    -n "${namespace}"
    upgrade "${old_release_name}" "${chart_repository}/${chart_name}"
    --version "${chart_version}"
    --allow-unreleased
    --reset-values
    --values -
    --detailed-exitcode
    --normalize-manifests
  )

  [[ "${#}" -gt 2 ]] &&
    helm_diff_args+=(
      --post-renderer "${ROOT}/scripts/helm-kustomize-post-renderer.sh"
      --post-renderer-args "${3}"
    )

  if ! echo "${values}" | helm_do "${1}" diff "${helm_diff_args[@]}"; then
    log_error "Detected unexpected differences between the existing Helm Release and the Helm Release installed by the Module."
    log_fatal "DO NOT UPGRADE"
  fi

  log_info "${new_release_name} acceptance test for cluster ${1} succeeded!"
}

_crossplane_render() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: _crossplane_render <sc|wc> <module_name>"
  fi

  log_info "Rendering ${2}"

  local tmpdir
  tmpdir="$(mktemp -d)"

  append_trap 'rm -r '"${tmpdir}" EXIT

  _crossplane_composition "${1}" "${2}" >"${tmpdir}/composition.yaml"

  _crossplane_functions "${1}" >"${tmpdir}/functions.yaml"

  _crossplane_xr "${1}" "${2}" >"${tmpdir}/xr.yaml"

  crossplane render "${tmpdir}/xr.yaml" "${tmpdir}/composition.yaml" "${tmpdir}/functions.yaml"
}

_crossplane_composition() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: _crossplane_composition <sc|wc> <configuration_name>"
  fi

  log_info "Extracting Composition from Configuration ${2}"

  local tmpdir
  tmpdir="$(mktemp -d)"

  append_trap 'rm -r '"${tmpdir}" EXIT

  local configuration_package
  configuration_package=$(helmfile_do "${1}" template -l name=crossplane-packages | yq 'select(.kind == "Configuration" and .metadata.name == "'"${2}"'").spec.package')

  if [ -z "${configuration_package}" ]; then
    log_fatal "Failed to determine package from Configuration ${2}"
  fi

  log_info "Found Configuration package: ${configuration_package}"

  crossplane xpkg extract "${configuration_package}" -o "${tmpdir}/out.gz"

  zcat "${tmpdir}/out.gz" | yq 'select(.kind == "Composition")'
}

_crossplane_functions() {
  if [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: _crossplane_functions <sc|wc>"
  fi

  log_info "Getting Functions that should be installed by Apps"

  helmfile_do "${1}" template -l name=crossplane-packages | yq 'select(.kind == "Function")'
}

_crossplane_xr() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: _crossplane_xr <sc|wc> <module_release_name>"
  fi

  log_info "Getting XR from ${2}"

  helmfile_do "${1}" template -l "name=${2}"
}
