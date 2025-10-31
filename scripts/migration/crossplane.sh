#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit

module_acceptance() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: module_acceptance <sc|wc> <module_name> [<helm-post-renderer-kustomization-dir>]"
  fi

  log_info "Running module acceptance test by comparing existing Helm Release ${2} in cluster ${1} with Module ${2}"

  local crossplane_release
  local release_namespace
  local chart_repository
  local chart_name
  local chart_version
  local values

  crossplane_release="$(_crossplane_render "${1}" "${2}" | yq 'select(.kind == "Release")')"

  crossplane_release_external_name=$(yq '.metadata.annotations["crossplane.io/external-name"]' <<<"${crossplane_release}")
  if [ "${crossplane_release_external_name}" != "${2}" ]; then
    log_error "Annotation 'crossplane.io/external-name' in Release in Module ${2} does not match existing Helm Release name"
    log_error "Expected: ${2}"
    log_error "Actual: ${crossplane_release_external_name}"
    log_fatal "DO NOT UPGRADE"
  fi

  release_namespace=$(yq '.spec.forProvider.namespace' <<<"${crossplane_release}")
  chart_repository=$(yq '.spec.forProvider.chart.repository' <<<"${crossplane_release}")
  chart_name=$(yq '.spec.forProvider.chart.name' <<<"${crossplane_release}")
  chart_version=$(yq '.spec.forProvider.chart.version' <<<"${crossplane_release}")
  values="$(yq -o json '.spec.forProvider.values' <<<"${crossplane_release}")"

  # FIXME: Currently null
  release_namespace="kube-system"

  helm_diff_args=(
    -n "${release_namespace}"
    upgrade "${2}" "${chart_repository}/${chart_name}"
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
    log_error "Detected unexpected differences between the existing Helm Release '${2}' and the Module '${2}'."
    log_fatal "DO NOT UPGRADE"
  fi

  log_info "Module ${2} acceptance test for cluster ${1} succeeded!"
}

_crossplane_render() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: _crossplane_render <sc|wc> <module_name>"
  fi

  log_info "Rendering Module ${2}"

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
    log_fatal "usage: _crossplane_composition <sc|wc> <module_name>"
  fi

  log_info "Extracting Composition from Module ${2}'s Configuration package"

  local tmpdir
  tmpdir="$(mktemp -d)"

  append_trap 'rm -r '"${tmpdir}" EXIT

  local configuration_package
  configuration_package=$(helmfile_do "${1}" template -l name=crossplane-packages | yq 'select(.kind == "Configuration" and .metadata.name == "'"module-${2}"'").spec.package')

  if [ -z "${configuration_package}" ]; then
    log_fatal "Failed to determine Configuration package from Module ${2}"
  fi

  log_info "Found Configuration package: ${configuration_package}"

  crossplane xpkg extract "${configuration_package}" -o "${tmpdir}/out.gz"

  zcat "${tmpdir}/out.gz" | yq 'select(.kind == "Composition")'
}

_crossplane_functions() {
  if [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: _crossplane_functions <sc|wc>"
  fi

  log_info "Getting Crossplane Functions that should be installed by Apps"

  helmfile_do "${1}" template -l name=crossplane-packages | yq 'select(.kind == "Function")'
}

_crossplane_xr() {
  if [[ "${#}" -lt 2 ]] || [[ ! "${1}" =~ ^(sc|wc)$ ]]; then
    log_fatal "usage: _crossplane_xr <sc|wc> <module_name>"
  fi

  log_info "Getting Crossplane XR from Module ${2}"

  helmfile_do "${1}" template -l "name=module-${2}"
}
