#!/usr/bin/env bash

# TODO:
# - add more tests
# - update sbom version per Welkin release
# - save manual overrides between runs (currently, and set-me's overrides are removed when running generate)
#   - currently, "generate" will retrieve "Elastisys evaluation" & "supplier" from existing SBOM and use that one always
#   - any other objects added manually will be removed when running generate
# - include images for all configurations? (e.g. different cloud providers can have unique images/charts)
#   - maybe, instead of using an existing environment, generate could create a new CK8S_CONFIG_PATH
#     - problem with this is, that currently, Helmfile template requires a KUBECONFIG
# - include licenses for images?
set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "${HERE}")"
HELMFILE_FOLDER="${ROOT}/helmfile.d"
SBOM_FILE="${ROOT}/docs/sbom.json"
SBOM_TEMPLATE_FILE="${ROOT}/docs/sbom.template.json"

# shellcheck source=bin/common.bash
source "${HERE}/common.bash"

usage() {
  echo "COMMANDS:" >&2
  echo "  add <component-name> <component-version> <key> <value>  add key-value pair to a component" >&2
  echo "  edit <component-name> <component-version> <key>         edit object under key for a component using $EDITOR" >&2
  echo "  generate                                                generate new cyclonedx sbom. GITHUB_TOKEN can be set to avoid GitHub rate limits" >&2
  echo "  get <component-name> [component-version] [key]          get component from sbom, optionally query for a provided key" >&2
  echo "  get-charts                                              get all charts in sbom" >&2
  echo "  get-containers                                          get all container images in sbom" >&2
  echo "  get-unset                                               get names of components with set-me's or missing licenses" >&2
  echo "  remove <component-name> <component-version> <key>       remove key for a component" >&2
  echo "  update-containers [component-name] [component-version]  update all container images in sbom"
  echo "  validate                                                validate SBOM using cyclonedx-cli" >&2
  exit 1
}

sbom_cyclonedx_validation() {
  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: sbom_cyclonedx_validation <sbom-file>"
  fi

  local sbom_file="${1}"
  if [[ ! -f "${sbom_file}" ]]; then
    log_fatal "SBOM file ${sbom_file} does not exist"
  fi

  log_info "Validating CycloneDX for SBOM file"
  cyclonedx validate --fail-on-errors --input-file "${sbom_file}" && true
  exit_code="$?"
  if ! ${CK8S_AUTO_APPROVE:-} && [[ "${exit_code}" != 0 ]]; then
    log_warning "CycloneDX Validation failed"
    ask_continue
  fi
}

# generic function for running yq queries with prompts for cyclonedx validation and to show diff before merging
_yq_run_query() {
  local sbom_file tmp_sbom_file query
  sbom_file="${1}"
  query="${2}"

  tmp_sbom_file=$(mktemp --suffix=-sbom.json)
  append_trap "rm ${tmp_sbom_file} >/dev/null 2>&1" EXIT

  if ! ${CK8S_SKIP_VALIDATION:-}; then
    yq -o json "${query}" "${sbom_file}" >"${tmp_sbom_file}"
    sbom_cyclonedx_validation "${tmp_sbom_file}"
  fi
  if ! ${CK8S_AUTO_APPROVE:-}; then
    diff -U3 --color=always "${sbom_file}" "${tmp_sbom_file}" && log_info "No change" && exit 0
    log_info "Changes found"
    ask_continue
  fi

  yq -i -o json "${query}" "${sbom_file}"
}

# function for updating values of existing components in a input sbom file
_sbom_edit_component() {
  local component_name component_version key sbom_file tmp_sbom_file query

  sbom_file="${1}"
  component_name="${2}"
  component_version="${3}"
  key="${4}"

  tmp_change=$(mktemp "--suffix=-update-${component_name}-sbom.json")
  append_trap "rm ${tmp_change} >/dev/null 2>&1" EXIT

  # check if key that should be updated exists
  has_key=$(yq -e -o json ".components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\") | has(\"${key}\")" "${sbom_file}")
  if [[ "${has_key}" == false ]]; then
    log_fatal "${key} not found"
  fi

  yq -e -o json ".components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\") | .${key}" "${sbom_file}" >"${tmp_change}"
  "${EDITOR}" "${tmp_change}"

  query="with(.components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\"); .${key} = $(jq -c '.' "${tmp_change}"))"

  _yq_run_query "${sbom_file}" "${query}"
}

# function for adding new values to existing components in a input sbom file given a key
_sbom_add_component() {
  local component_name component_version key sbom_file tmp_sbom_file value query

  sbom_file="${1}"
  component_name="${2}"
  component_version="${3}"
  key="${4}"
  value="${5}"

  if [[ ! "${key}" =~ ^(components|evidence|licenses|properties|supplier)$ ]]; then
    log_fatal "unsupported key \"${key}\", currently only supports \"components|evidence|licenses|properties|supplier\""
  fi

  # change the query depending on if the key is a known array type in cyclonedx 1.6 spec
  append_query="= ${value}"
  value_type="{}"
  if [[ "${key}" =~ ^(components|licenses|properties)$ ]]; then
    value_type="[]"
    append_query="|= (. + ${value} | unique_by([.name, .version]))"
  fi

  # check if key that should be updated exists
  has_key=$(yq -o json ".components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\") | has(\"${key}\")" "${sbom_file}")
  if [[ "${has_key}" == false ]]; then
    _yq_run_query "${sbom_file}" "with(.components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\"); .${key} = ${value_type})"
  fi

  query="with(.components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\"); .${key} ${append_query})"

  _yq_run_query "${sbom_file}" "${query}"
}

# checks if a license is listed as a supported license id
_id_or_name_license() {
  local license="${1}"
  if [[ $(curl --silent https://cyclonedx.org/schema/spdx.schema.json | yq -r ".enum | contains([\"${license}\"])") == "true" ]]; then
    echo "id"
    return
  fi
  echo "name"
}

# format license json object
# ref: https://cyclonedx.org/docs/1.6/json/#components_items_licenses_oneOf_i0_items_license
_format_license_object() {
  local license="${1}"
  echo "{\"license\": {\"$(_id_or_name_license "${license}")\": \"${license}\"}}"
}

# format supplier json object
# ref: https://cyclonedx.org/docs/1.6/json/#components_items_supplier
_format_supplier_object() {
  local supplier="${1}"
  echo "{\"name\": \"${supplier}\"}"
}

# format location json object
# ref: https://cyclonedx.org/docs/1.6/json/#components_items_evidence_occurrences_items_location
_format_location_object() {
  local location="${1}"
  echo "{\"occurrences\": [{\"location\": \"${location}\"}]}"
}

# format properties json object
# ref: https://cyclonedx.org/docs/1.6/json/#components_items_properties
_format_property_object() {
  local name value
  name="${1}"
  value="${2}"
  echo "{\"name\": \"${name}\", \"value\": \"${value}\"}"
}

_format_elastisys_evaluation_object() {
  local evaluation="${1}"
  _format_property_object "Elastisys evaluation" "${evaluation}"
}

# format component json object for a container image
# ref: https://cyclonedx.org/docs/1.6/json/#components
_format_container_component_object() {
  local container="${1}"
  name="${container%%:*}"
  version="${container##*:}"
  bom_ref="pkg:oci/${container}"
  echo "{\"name\": \"${name}\", \"version\": \"${version}\", \"type\": \"container\", \"bom-ref\": \"${bom_ref}\"}"
}

_prepare_sbom() {
  local sbom_file
  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: _prepare_sbom <sbom-file>"
  fi

  sbom_file="${1}"
  if [[ ! -f "${sbom_file}" ]]; then
    log_fatal "SBOM file ${sbom_file} does not exist"
  fi
  log_info "Preparing SBOM"

  project_version="$(git name-rev --tags --name-only "$(git rev-parse HEAD)")"
  if [[ "${project_version}" == "undefined" ]]; then
    project_version="$(git rev-parse HEAD)"
  fi

  cdxgen --project-name "welkin-apps" --project-version "${project_version}" --filter '.*' -t helm "${HELMFILE_FOLDER}" --output "${sbom_file}"

  sbom_version=$(yq -o json ".version" "${SBOM_FILE}")
  yq -o json -i ".version = \"${sbom_version}\"" "${sbom_file}"
  yq -o json -i ". *= load(\"${SBOM_TEMPLATE_FILE}\")" "${sbom_file}"

  mapfile -t components < <(sbom_get_charts "${sbom_file}")

  # adding "Elastisys evaluation" & "supplier" objects that currently needs to be configured manually
  for component in "${components[@]}"; do
    component_name=$(echo "${component}" | jq -r '.name')
    component_version=$(echo "${component}" | jq -r '.version')

    # check if component already has an elastisys evaluation
    elastisys_evaluation=$(yq -o json -I=0 ".components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\").properties[] | select(.name == \"Elastisys evaluation\")" "${SBOM_FILE}")
    if [[ -z "${elastisys_evaluation}" ]] || [[ "${elastisys_evaluation}" == null ]]; then
      elastisys_evaluation="$(_format_elastisys_evaluation_object "set-me")"
    fi
    _sbom_add_component "${sbom_file}" "${component_name}" "${component_version}" "properties" "${elastisys_evaluation}"

    supplier=$(yq -o json -I=0 ".components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\").supplier" "${SBOM_FILE}")
    if [[ -z "${supplier}" ]] || [[ "${supplier}" == null ]]; then
      supplier="$(_format_supplier_object "set-me")"
    fi
    _sbom_add_component "${sbom_file}" "${component_name}" "${component_version}" "supplier" "${supplier}"
  done
}

_get_licenses() {
  local sbom_file
  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: _get_licenses <sbom-file>"
  fi

  sbom_file="${1}"
  if [[ ! -f "${sbom_file}" ]]; then
    log_fatal "SBOM file ${sbom_file} does not exist"
  fi
  log_info "Getting licenses"

  # Upstream charts
  # TODO: (maybe) filter out unused charts before processing?
  mapfile -t upstream_charts < <(find "${HELMFILE_FOLDER}/upstream" -name "Chart.yaml")

  for chart in "${upstream_charts[@]}"; do
    chart_name=$(yq ".name" "${chart}")
    chart_version=$(yq ".version" "${chart}")

    # check if chart.yaml contains license in annotations
    annotation=$(yq ".annotations.licenses" "${chart}")
    annotation_artifacthub=$(yq ".annotations.artifacthub.io/license" "${chart}")

    if [[ -n "${annotation}" && "${annotation}" != "null" ]]; then
      _sbom_add_component "${sbom_file}" "${chart_name}" "${chart_version}" "licenses" "$(_format_license_object "${annotation}")"

    elif [[ -n "${annotation_artifacthub}" && "${annotation_artifacthub}" != "null" ]]; then
      _sbom_add_component "${sbom_file}" "${chart_name}" "${chart_version}" "licenses" "$(_format_license_object "${annotation_artifacthub}")"

    # if no license in annotations, try to get from source (e.g. github)
    else
      mapfile -t sources < <(yq '.sources[]' "${chart}")
      if [[ "${#sources[@]}" -eq 0 ]] || [[ "${sources[*]}" == "null" ]]; then
        continue
      else
        for source in "${sources[@]}"; do
          # TODO: assumes GitHub source, this is not necessarily guaranteed
          repo=${source##*github.com/}

          # API rate limits :grimacing:
          mapfile -t licenses_in_git < <(curl -L -s \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            "https://api.github.com/repos/${repo}" | jq -r '.license.name')

          if [[ "${licenses_in_git[*]}" == "null" ]]; then
            continue
          else
            for l in "${licenses_in_git[@]}"; do
              _sbom_add_component "${sbom_file}" "${chart_name}" "${chart_version}" "licenses" "$(_format_license_object "${l}")"
            done
          fi
        done
      fi
    fi
  done

  # Welkin charts
  mapfile -t welkin_charts < <(find "${HELMFILE_FOLDER}/charts" -name "Chart.yaml")

  for chart in "${welkin_charts[@]}"; do
    chart_name=$(yq ".name" "${chart}")
    chart_version=$(yq ".version" "${chart}")

    # TODO: licenses for the applications
    _sbom_add_component "${sbom_file}" "${chart_name}" "${chart_version}" "licenses" "$(_format_license_object "Apache-2.0")"
  done
}

# generates manifests for each release using helmfile template adding the chart location as an annotation used later for mapping images to components in the sbom
_generate_helmfile_template_file() {
  template_file="${1}"

  log_info "Preparing Helmfile templates"

  log_info "  - Workload"
  mapfile -t releases_workload < <(helmfile -f "${HELMFILE_FOLDER}" -e workload_cluster list --output json 2>/dev/null | yq -I=0 -o json '.[] | select(.enabled == true and .installed == true) | {"location": .chart, "name": .name}')
  for release in "${releases_workload[@]}"; do
    release_name=$(yq '.name' <<<"${release}")
    release_location="helmfile.d/$(yq '.location' <<<"${release}")"
    helmfile -f "${HELMFILE_FOLDER}" -e workload_cluster template -l "name=${release_name}" 2>/dev/null | yq ".metadata.annotations.release = \"${release_location}\"" >>"${template_file}"
  done

  log_info "  - Service"
  mapfile -t releases_service < <(helmfile -f "${HELMFILE_FOLDER}" -e service_cluster list --output json 2>/dev/null | yq -I=0 -o json '.[] | select(.enabled == true and .installed == true) | {"location": .chart, "name": .name}')
  for release in "${releases_service[@]}"; do
    release_name=$(yq '.name' <<<"${release}")
    release_location="helmfile.d/$(yq '.location' <<<"${release}")"
    helmfile -f "${HELMFILE_FOLDER}" -e service_cluster template -l "name=${release_name}" 2>/dev/null | yq ".metadata.annotations.release = \"${release_location}\"" >>"${template_file}"
  done
}

# adds container images for a specific resource type and chart release based on its location to a input sbom file
_add_container_images_from_template() {
  local sbom_file template_file chart_name type query
  sbom_file="${1}"
  template_file="${2}"
  chart_name="${3}"
  chart_version="${4}"
  location="${5}"
  type="${6}"

  chart_query="(.metadata.annotations.release == \"${location}\")"

  if [[ "${type}" == "pod" ]]; then
    query="select(.kind == \"Pod\" and ${chart_query}) | .spec | ((.initContainers[] | .image), (.containers[] | .image))"
  elif [[ "${type}" == "cronjob" ]]; then
    query="select(.kind == \"CronJob\" and ${chart_query}) | .spec.jobTemplate.spec.template.spec | ((.initContainers[] | .image), (.containers[] | .image))"
  elif [[ "${type}" == "daemonset" ]]; then
    query="select(.kind == \"DaemonSet\" and ${chart_query}) | .spec.template.spec | ((.initContainers[] | .image), (.containers[] | .image))"
  elif [[ "${type}" == "deployment" ]]; then
    query="select(.kind == \"Deployment\" and ${chart_query}) | .spec.template.spec | ((.initContainers[] | .image), (.containers[] | .image))"
  elif [[ "${type}" == "job" ]]; then
    query="select(.kind == \"Job\" and ${chart_query}) | .spec.template.spec | ((.initContainers[] | .image), (.containers[] | .image))"
  elif [[ "${type}" == "statefulset" ]]; then
    query="select(.kind == \"StatefulSet\" and ${chart_query}) | .spec.template.spec | ((.initContainers[] | .image), (.containers[] | .image))"
  elif [[ "${type}" == "alertmanager" ]]; then
    # TODO: user-alertmanager Alertmanager resource deployed in its own chart currently does not include the image in the template (switching to kps solves this)
    query="select(.kind == \"Alertmanager\" and ${chart_query}) | .spec.image"
  elif [[ "${type}" == "prometheus" ]]; then
    query="select(.kind == \"Prometheus\" and ${chart_query}) | .spec.image"
  fi

  mapfile -t containers < <(yq "${query}" "${template_file}" | sed '/---/d' | sort -u)

  if [[ ${#containers[@]} -eq 0 ]]; then
    return
  fi

  for container in "${containers[@]}"; do
    _sbom_add_component "${sbom_file}" "${chart_name}" "${chart_version}" "components" "$(_format_container_component_object "${container}")"
  done
}

# add images for each type for a chart release
_add_container_images_for_component() {
  _add_container_images_from_template "${@}" "cronjob"
  _add_container_images_from_template "${@}" "pod"
  _add_container_images_from_template "${@}" "deployment"
  _add_container_images_from_template "${@}" "job"
  _add_container_images_from_template "${@}" "daemonset"
  _add_container_images_from_template "${@}" "statefulset"
  _add_container_images_from_template "${@}" "alertmanager"
  _add_container_images_from_template "${@}" "prometheus"
}

# loops over all charts included in the sbom and adds templated container images to a input sbom file
_add_container_images() {
  local sbom_file
  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: _add_container_images <sbom-file>"
  fi

  sbom_file="${1}"
  if [[ ! -f "${sbom_file}" ]]; then
    log_fatal "SBOM file ${sbom_file} does not exist"
  fi

  template_file=$(mktemp --suffix=-template_file)
  append_trap "rm ${template_file} >/dev/null 2>&1" EXIT
  _generate_helmfile_template_file "${template_file}"

  log_info "Getting container images"

  mapfile -t all_charts < <(sbom_get_charts "${sbom_file}")

  for chart in "${all_charts[@]}"; do
    chart_name=$(yq ".name" <<<"${chart}")
    chart_version=$(yq ".version" <<<"${chart}")
    location=$(yq ".location" <<<"${chart}")

    _add_container_images_for_component "${sbom_file}" "${template_file}" "${chart_name}" "${chart_version}" "${location}"
  done
}

# adds chart locations for all components in a input sbom file
_add_locations() {
  local chart_name chart_version sbom_file
  sbom_file="${1}"

  log_info "Getting locations"
  mapfile -t all_charts < <(find "${HELMFILE_FOLDER}" -name "Chart.yaml")
  for chart in "${all_charts[@]}"; do
    chart_name=$(yq ".name" "${chart}")
    chart_version=$(yq ".version" "${chart}")
    location="${chart#"${ROOT}/"}"
    location="${location%/Chart.yaml}"
    _sbom_add_component "${sbom_file}" "${chart_name}" "${chart_version}" "evidence" "$(_format_location_object "${location}")"
  done
}

sbom_remove() {
  if [[ "$#" -ne 4 ]]; then
    usage
  fi

  local component_name component_version key value

  component_name="${1}"
  component_version="${2}"
  key="${3}"
  value="${4}"

  query="with(.components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\").${key}; del(.[] | select(.name == \"${value}\")))"

  _yq_run_query "${SBOM_FILE}" "${query}"
}

sbom_add() {
  if [[ "$#" -ne 4 ]]; then
    usage
  fi

  local component_name component_version key

  component_name="${1}"
  component_version="${2}"
  key="${3}"

  _sbom_add_component "${SBOM_FILE}" "${@}"
  yq -o json -i '.version += 1' "${SBOM_FILE}"
  log_info "Updated ${key} for ${component_name}@${component_version}"
}

sbom_get() {
  if [[ "$#" -lt 1 ]]; then
    usage
  fi

  local component_name component_version key query

  component_name="${1}"
  query=".components[] | select(.name == \"${component_name}\" )"
  if [[ "$#" -gt 1 ]]; then
    component_version="${2}"
    query=".components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\")"
  fi
  if [[ "$#" -gt 2 ]]; then
    key="${3}"
    query=".components[] | select(.name == \"${component_name}\" and .version == \"${component_version}\") | .${key}"
  fi

  yq -e -o json "${query}" "${SBOM_FILE}"
}

sbom_get_unset() {
  log_info "Getting components without licenses"
  yq -I=0 -o json -r '[.components[] | select(.licenses[].license.name | contains("set-me")) | { "name": .name, "version": .version}] | .[]' "${SBOM_FILE}"
  yq -I=0 -o json -r '[.components[] | select(.licenses | length == 0) | { "name": .name, "version": .version}] | .[]' "${SBOM_FILE}"
  yq -I=0 -o json -r '[.components[] | select(has("licenses") == "false") | { "name": .name, "version": .version}] | .[]' "${SBOM_FILE}"

  echo
  log_info "Getting components without Elastisys evaluation"
  yq -I=0 -o json -r '[.components[] | select(.properties[].value == "set-me")  | { "name": .name, "version": .version}] | .[]' "${SBOM_FILE}"

  echo
  log_info "Getting components without supplier"
  yq -I=0 -o json -r '[.components[] | select(.supplier.name == "set-me")  | { "name": .name, "version": .version}] | .[]' "${SBOM_FILE}"
}

sbom_get_charts() {
  local query sbom_file
  sbom_file="${1}"
  query='[.components[] | { "name": .name, "version": .version, "location": .evidence.occurrences[0].location}] | .[]'

  yq -e -o json -I=0 "${query}" "${sbom_file}"
}

sbom_get_containers() {
  local query
  query='.components[] | [.components[] | { "name": .name, "version": .version}] | .[]'

  yq -e -o json --colors -I=0 "${query}" "${SBOM_FILE}" | sort -u
}

sbom_edit() {
  if [[ "$#" -ne 3 ]]; then
    usage
  fi

  local component_name key

  component_name="${1}"
  key="${2}"

  _sbom_edit_component "${SBOM_FILE}" "${@}"
  yq -o json -i '.version += 1' "${SBOM_FILE}"
  log_info "Updated ${key} for ${component_name}"
}

sbom_update_containers() {
  local tmp_sbom_file query
  tmp_sbom_file=$(mktemp --suffix=-update-containers-sbom.json)
  append_trap "rm ${tmp_sbom_file} >/dev/null 2>&1" EXIT

  cdxgen --filter '.*' -t helm "${HELMFILE_FOLDER}" --output "${tmp_sbom_file}"

  if [[ "$#" -gt 0 ]]; then
    chart_name="${1}"
    if [[ "$#" -gt 1 ]]; then
      chart_version="${2}"
      if [[ ! $(sbom_get "${chart_name}" "${chart_version}") ]]; then
        log_fatal "${chart_name} not found with version ${chart_version}"
      fi
    else
      # TODO: handle multiple versions (e.g. Grafana)
      chart_version="$(sbom_get "${chart_name}" | jq -r '.version')"
      log_info "No chart version provided, will use version found in SBOM: ${chart_version}"
    fi
    template_file=$(mktemp --suffix=-template_file)
    append_trap "rm ${template_file} >/dev/null 2>&1" EXIT

    log_info "Updating container images for ${chart_name}@${chart_version} in SBOM"
    _generate_helmfile_template_file "${template_file}"
    CK8S_AUTO_APPROVE=true CK8S_SKIP_VALIDATION=true _add_container_images_for_component "${tmp_sbom_file}" "${template_file}" "${chart_name}" "${chart_version}"
  else
    log_info "Updating all container images in SBOM"
    CK8S_AUTO_APPROVE=true CK8S_SKIP_VALIDATION=true _add_container_images "${tmp_sbom_file}"
  fi

  query=". *d load(\"${tmp_sbom_file}\")"
  _yq_run_query "${SBOM_FILE}" "${query}"
  yq -o json -i '.version += 1' "${SBOM_FILE}"
}

sbom_generate() {
  local tmp_sbom_file
  tmp_sbom_file=$(mktemp --suffix=-generate-sbom.json)
  append_trap "rm ${tmp_sbom_file} >/dev/null 2>&1" EXIT

  # TODO: figure out a different approach for retrieving licenses, or handle GITHUB_TOKEN better
  : "${GITHUB_TOKEN:?Missing GITHUB_TOKEN}"

  config_load "sc"
  config_load "wc"

  export CK8S_AUTO_APPROVE=true
  export CK8S_SKIP_VALIDATION=true

  if [[ ! -f "${SBOM_FILE}" ]]; then
    log_info "SBOM file does not exists, creating new"
    touch "${SBOM_FILE}"
  fi

  _prepare_sbom "${tmp_sbom_file}"

  _get_licenses "${tmp_sbom_file}"

  _add_locations "${tmp_sbom_file}"

  _add_container_images "${tmp_sbom_file}"

  CK8S_AUTO_APPROVE=false
  CK8S_SKIP_VALIDATION=false
  sbom_cyclonedx_validation "${tmp_sbom_file}"

  diff -U3 --color=always "${SBOM_FILE}" "${tmp_sbom_file}" && return
  log_warning_no_newline "Do you want to replace SBOM file? (y/N): "
  read -r reply
  if [[ "${reply}" == "y" ]]; then
    mv "${tmp_sbom_file}" "${SBOM_FILE}"
    yq -o json -i '.version += 1' "${SBOM_FILE}"
    log_info "SBOM file replaced"
    return
  fi
  log_info "Skipped replacing SBOM"
}

case "${1}" in
add)
  shift
  sbom_add "${@}"
  ;;
edit)
  shift
  sbom_edit "${@}"
  ;;
generate)
  shift
  sbom_generate "${@}"
  ;;
get)
  shift
  sbom_get "${@}"
  ;;
get-charts)
  shift
  sbom_get_charts "${SBOM_FILE}"
  ;;
get-containers)
  shift
  sbom_get_containers
  ;;
get-unset)
  shift
  sbom_get_unset "${@}"
  ;;
remove)
  shift
  sbom_remove "${@}"
  ;;
update-containers)
  shift
  sbom_update_containers "${@}"
  ;;
validate)
  sbom_cyclonedx_validation "${SBOM_FILE}"
  ;;
*) usage ;;
esac
