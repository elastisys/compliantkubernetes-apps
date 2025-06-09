#!/usr/bin/env bash

# TODO:
# - add more tests
# - save manual overrides between runs (currently, and set-me's overrides are removed when running generate)
#   - currently, "generate" will retrieve "Elastisys evaluation" & "supplier" from existing SBOM and use that one always
#   - any other objects added manually will be removed when running generate
# - include images for all configurations? (e.g. different cloud providers can have unique images/charts)
# - include licenses for images?
# - consistently update timestamp? e.g. when running sbom add or edit
set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "$(dirname "${HERE}")")"
HELMFILE_FOLDER="${ROOT}/helmfile.d"
SBOM_FILE="${ROOT}/docs/sbom.json"
SBOM_TEMPLATE_FILE="${ROOT}/docs/sbom.template.json"

# TODO: setting config path here to be able to source common.bash
tmp_config_path=$(mktemp -d --suffix -sbom-config-path)
export CK8S_CONFIG_PATH="${tmp_config_path}"

# shellcheck source=bin/common.bash
source "${ROOT}/bin/common.bash"
append_trap "rm -rf ${tmp_config_path} >/dev/null 2>&1" EXIT
# TODO: sources test scripts to set up new Welkin config, this could be generalized to not rely on test path
source "${ROOT}/tests/common/bats/env.bash"
source "${ROOT}/tests/common/bats/gpg.bash"
source "${ROOT}/tests/common/bats/yq.bash"

usage() {
  echo "COMMANDS:" >&2
  echo "  add <location> <key> <value> [property-value]   add key-value pair to a component" >&2
  echo "  diff                                            checks if any changes in git requires sbom to be updated" >&2
  echo "  edit <location> <key>                           edit object under key for a component using ${EDITOR:-}" >&2
  echo "  generate [--version version]                    generate new cyclonedx sbom. Requires GITHUB_TOKEN to be set to avoid GitHub rate limits" >&2
  echo "  get <location> [key]                            get component from sbom, optionally query for a provided key" >&2
  echo "  get-charts                                      get all charts in sbom" >&2
  echo "  get-containers                                  get all container images in sbom" >&2
  echo "  get-unset                                       get names of components with set-me's or missing licenses" >&2
  echo "  remove <location> <value>                       remove a property for a component" >&2
  echo "  update <location>                               update SBOM for a single component using chart location"
  echo "  validate                                        validate SBOM using cyclonedx-cli" >&2
  exit 1
}

_init_welkin_config() {
  log_info "Initializing Welkin config used for generating Welkin"
  export PATH="${ROOT}/bin:${PATH}"
  gpg.setup_one >/dev/null 2>&1
  # append_trap "gpg.teardown" EXIT
  env.setup >/dev/null 2>&1
  env.init "${@}"
  yq.set 'common' '.kured.enabled' 'true'
  yq.set 'common' '.kyverno.enabled' 'true'
  yq.set 'common' '.gpu.enabled' 'true'
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

  yq -o json -i "${query}" "${sbom_file}"
}

# function for updating values of existing components in a input sbom file
_sbom_edit_component() {
  local key location sbom_file tmp_sbom_file query

  sbom_file="${1}"
  location="${2}"
  key="${3}"

  tmp_change=$(mktemp "--suffix=-edit-sbom.json")
  append_trap "rm ${tmp_change} >/dev/null 2>&1" EXIT

  # check if key that should be updated exists
  has_key=$(yq -e -o json ".components[] | select(.evidence.occurrences[0].location == \"${location}\") | has(\"${key}\")" "${sbom_file}")
  if [[ "${has_key}" == false ]]; then
    log_fatal "${key} not found"
  fi

  yq -e -o json ".components[] | select(.evidence.occurrences[0].location == \"${location}\") | .${key}" "${sbom_file}" >"${tmp_change}"
  "${EDITOR:-}" "${tmp_change}"

  query="with(.components[] | select(.evidence.occurrences[0].location == \"${location}\"); .${key} = $(jq -c '.' "${tmp_change}"))"

  _yq_run_query "${sbom_file}" "${query}"
}

# function for adding new values to existing components in a input sbom file given a key
_sbom_add_component() {
  local location key sbom_file tmp_sbom_file value query

  sbom_file="${1}"
  location="${2}"
  key="${3}"
  value="${4}"

  if [[ ! "${key}" =~ ^(components|licenses|properties|supplier)$ ]]; then
    log_fatal "unsupported key \"${key}\", currently only supports \"components|licenses|evidence|properties|supplier\""
  fi

  # change the query depending on if the key is a known array type in cyclonedx 1.6 spec
  value_type="[]"
  if [[ "${key}" == components ]]; then
    append_query="|= (. + $(_format_container_component_object "${value}") | unique_by([.name, .version]))"
  elif [[ "${key}" == licenses ]]; then
    append_query="|= (. + $(_format_license_object "${value}") | unique_by([.name, .version]))"
  elif [[ "${key}" == properties ]]; then
    property_value="${5}"
    append_query="|= (. + $(_format_property_object "${value}" "${property_value}") | unique_by([.name, .version]))"
  elif [[ "${key}" == supplier ]]; then
    value_type="{}"
    append_query="= $(_format_supplier_object "${value}")"
  fi

  # check if key that should be updated exists
  has_key=$(yq -o json ".components[] | select(.evidence.occurrences[0].location == \"${location}\") | has(\"${key}\")" "${sbom_file}")

  if [[ "${has_key}" == false ]]; then
    CK8S_AUTO_APPROVE=true _yq_run_query "${sbom_file}" "with(.components[] | select(.evidence.occurrences[0].location == \"${location}\"); .${key} = ${value_type})"
  fi

  query="with(.components[] | select(.evidence.occurrences[0].location == \"${location}\"); .${key} ${append_query})"

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

# format component json object for a container image
# ref: https://cyclonedx.org/docs/1.6/json/#components
_format_dependency_object() {
  local component_bom_ref="${1}"
  echo "{\"ref\": \"${component_bom_ref}\", \"dependsOn\": []}"
}

_prepare_sbom() {
  local full_path_location location project_version sbom_file
  if [[ "$#" -lt 1 ]] || [[ "$#" -gt 3 ]]; then
    log_fatal "usage: _prepare_sbom <sbom-file> [--version version] [--location location]"
  fi

  # TODO: hardcoded provider and installer for now, look into running for all combinations (either merge or create unique SBOMs for each?)
  _init_welkin_config baremetal kubespray prod

  sbom_file="${1}"

  log_info "Preparing SBOM"

  shift
  project_version=""
  full_path_location=""
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
    --version)
      project_version="${2}"
      shift
      ;;
    --location)
      full_path_location="${2}"
      shift
      ;;
    *)
      log_fatal "usage: _prepare_sbom <sbom-file> [--version version] [--location location]"
      ;;
    esac
    shift
  done

  if [[ -z "${project_version}" ]]; then
    project_version="$(git name-rev --tags --name-only "$(git rev-parse HEAD)")"
    if [[ "${project_version}" == "undefined" ]]; then
      project_version="$(git rev-parse HEAD)"
    fi
  fi

  if [[ -n "${full_path_location}" ]]; then
    cdxgen --project-name "welkin-apps" --project-version "${project_version}" --filter '.*' --filter '.x.x' -t helm "${full_path_location}" --output "${sbom_file}"
    _add_location_for_component "${sbom_file}" "${full_path_location}/Chart.yaml"
  else
    cdxgen --project-name "welkin-apps" --project-version "${project_version}" --filter '.*' --filter '.x.x' -t helm "${HELMFILE_FOLDER}" --output "${sbom_file}"
    _add_locations "${sbom_file}"
  fi

  sbom_version=$(yq -r -o json ".version" "${SBOM_FILE}")
  yq -o json -i ".version = ${sbom_version}" "${sbom_file}"
  yq -o json -i ". *= load(\"${SBOM_TEMPLATE_FILE}\")" "${sbom_file}"

  mapfile -t components < <(sbom_get_charts "${sbom_file}")

  # adding "Elastisys evaluation" & "supplier" objects that currently needs to be configured manually
  for component in "${components[@]}"; do
    location=$(jq -r '.location' <<<"${component}")

    # check if component already has an elastisys evaluation
    elastisys_evaluation=$(yq -o json -r ".components[] | select(.evidence.occurrences[0].location == \"${location}\").properties[] | select(.name == \"Elastisys evaluation\").value" "${SBOM_FILE}")
    if [[ -z "${elastisys_evaluation}" ]] || [[ "${elastisys_evaluation}" == null ]]; then
      elastisys_evaluation="set-me"
    fi
    _sbom_add_component "${sbom_file}" "${location}" "properties" "Elastisys evaluation" "${elastisys_evaluation}"

    supplier=$(yq -o json -r ".components[] | select(.evidence.occurrences[0].location == \"${location}\").supplier.name" "${SBOM_FILE}")
    _sbom_add_component "${sbom_file}" "${location}" "supplier" "${supplier}"
  done
}

_add_dependencies() {
  local sbom_file="${1}"

  log_info "Updating container dependencies"

  mapfile -t components < <(sbom_get_charts "${sbom_file}")

  for component in "${components[@]}"; do
    location=$(jq -r '.location' <<<"${component}")
    component_bom_ref=$(sbom_get "${sbom_file}" "${location}" | jq -r '."bom-ref"')

    # check if a dependency exists for component ref
    has_ref=$(yq ".dependencies[] | select(.ref == \"${component_bom_ref}\")" "${sbom_file}")

    if [[ -z "${has_ref}" ]]; then
      query=".dependencies |= (. + $(_format_dependency_object "${component_bom_ref}") | unique_by(.ref))"
      CK8S_AUTO_APPROVE=true _yq_run_query "${sbom_file}" "${query}"
    fi

    mapfile -t container_bom_refs < <(sbom_get "${sbom_file}" "${location}" components | jq -r '.[]? | ."bom-ref"')
    for container_bom_ref in "${container_bom_refs[@]}"; do
      query="with(.dependencies[] | select(.ref == \"${component_bom_ref}\").dependsOn; . |= (. + \"${container_bom_ref}\") | unique)"
      _yq_run_query "${sbom_file}" "${query}"
    done
  done
}

# get licenses for specific input component
_add_license_for_component() {
  local chart chart_location chart_name chart_version location sbom_file
  sbom_file="${1}"
  chart="${2}"

  location="$(yq ".location" <<<"${chart}")"
  chart_location="${ROOT}/${location}/Chart.yaml"
  chart_name=$(yq ".name" <<<"${chart}")
  chart_version=$(yq ".version" <<<"${chart}")

  # if chart exists as part of Welkins own charts, adds Apache-2.0 license
  if [[ "${chart_location}" == *"helmfile.d/charts"* ]]; then
    _sbom_add_component "${sbom_file}" "${location}" "licenses" "Apache-2.0"
    return
  fi

  # check if chart.yaml contains license in annotations
  annotation=$(yq ".annotations.licenses" "${chart_location}")
  annotation_artifacthub=$(yq '.annotations."artifacthub.io/license"' "${chart_location}")

  if [[ -n "${annotation}" && "${annotation}" != "null" ]]; then
    _sbom_add_component "${sbom_file}" "${location}" "licenses" "${annotation}"

  elif [[ -n "${annotation_artifacthub}" && "${annotation_artifacthub}" != "null" ]]; then
    _sbom_add_component "${sbom_file}" "${location}" "licenses" "${annotation_artifacthub}"

  # if no license in annotations, try to get from source (i.e. github)
  else
    mapfile -t sources < <(yq '.sources[]' "${chart_location}")
    if [[ "${#sources[@]}" -eq 0 ]] || [[ "${sources[*]}" == "null" ]]; then
      mapfile -t licenses < <(yq -o json -r ".components[] | select(.evidence.occurrences[0].location == \"${location}\").licenses[].license | .name // .id" "${SBOM_FILE}")
      for license in "${licenses[@]}"; do
        _sbom_add_component "${sbom_file}" "${location}" "licenses" "${license}"
      done
    else
      for source in "${sources[@]}"; do
        if [[ "${source}" != *"github.com"* ]]; then
          # TODO: currently only supports GitHub source, this is not necessarily guaranteed
          continue
        fi

        # parsing the github repo to be able to use it through the github api endpoint
        repo=${source##*github.com/}
        repo=$(awk -F'/' '{print $1 "/" $2}' <<<"${repo}")
        repo=${repo%.git}

        # API rate limits :grimacing:
        mapfile -t licenses_in_git < <(curl -L -s \
          -H "Accept: application/vnd.github+json" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          -H "Authorization: Bearer ${GITHUB_TOKEN}" \
          "https://api.github.com/repos/${repo}" | jq -r '.license.name')

        if [[ "${licenses_in_git[*]}" != "null" ]]; then
          for license in "${licenses_in_git[@]}"; do
            _sbom_add_component "${sbom_file}" "${location}" "licenses" "${license}"
          done
        fi
      done
    fi
  fi
}

# gets licenses for all charts added as components in input sbom file
_add_licenses() {
  local chart_name chart_version sbom_file
  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: _add_licenses <sbom-file>"
  fi

  sbom_file="${1}"

  log_info "Getting licenses"

  # TODO: (maybe) filter out unused charts before processing?
  mapfile -t all_charts < <(sbom_get_charts "${sbom_file}")

  for chart in "${all_charts[@]}"; do
    _add_license_for_component "${sbom_file}" "${chart}"
  done
}

# generates manifests for each release using helmfile template adding the chart location as an annotation used later for mapping images to components in the sbom
_generate_helmfile_template_file() {
  local location release_name release_location
  template_file="${1}"

  log_info "Preparing Helmfile templates"

  select_query='.[] | select(.enabled == true and .installed == true) | {"location": .chart, "name": .name}'
  if [[ "$#" -gt 1 ]]; then
    location="${2#"${ROOT}/helmfile.d/"}"
    select_query=".[] | select(.enabled == true and .installed == true and .chart == \"${location}\") | {\"location\": .chart, \"name\": .name}"
  fi

  log_info "  - Workload"
  mapfile -t releases_workload < <(helmfile -f "${HELMFILE_FOLDER}" -e workload_cluster list --output json 2>/dev/null | yq -I=0 -o json "${select_query}")
  for release in "${releases_workload[@]}"; do
    release_name=$(yq '.name' <<<"${release}")
    release_location="helmfile.d/$(yq '.location' <<<"${release}")"
    helmfile -f "${HELMFILE_FOLDER}" -e workload_cluster template -l "name=${release_name}" 2>/dev/null | yq ".metadata.annotations.release = \"${release_location}\"" >>"${template_file}"
  done

  log_info "  - Service"
  mapfile -t releases_service < <(helmfile -f "${HELMFILE_FOLDER}" -e service_cluster list --output json 2>/dev/null | yq -I=0 -o json "${select_query}")
  for release in "${releases_service[@]}"; do
    release_name=$(yq '.name' <<<"${release}")
    release_location="helmfile.d/$(yq '.location' <<<"${release}")"
    helmfile -f "${HELMFILE_FOLDER}" -e service_cluster template -l "name=${release_name}" 2>/dev/null | yq ".metadata.annotations.release = \"${release_location}\"" >>"${template_file}"
  done
}

# adds container images for a specific resource type and chart release based on its location to a input sbom file
_add_container_images_from_template() {
  local chart_location chart_name chart_version location sbom_file template_file query
  sbom_file="${1}"
  template_file="${2}"
  chart="${3}"
  type="${4}"

  chart_name=$(yq ".name" <<<"${chart}")
  chart_version=$(yq ".version" <<<"${chart}")
  chart_location=$(yq ".location" <<<"${chart}")

  chart_query="(.metadata.annotations.release == \"${chart_location}\")"

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
    if [[ "${container}" == "null" ]]; then
      container="set-me"
    fi
    _sbom_add_component "${sbom_file}" "${chart_location}" "components" "${container}"
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
  local chart sbom_file template_file
  if [[ "$#" -lt 1 ]] || [[ "$#" -gt 2 ]]; then
    log_fatal "usage: _add_container_images <sbom-file>"
  fi

  sbom_file="${1}"

  template_file=$(mktemp --suffix=-sbom-template-file)
  append_trap "rm ${template_file} >/dev/null 2>&1" EXIT

  shift
  # check if should only generate templates for one specific chart based on location
  _generate_helmfile_template_file "${template_file}" "${@}"

  log_info "Getting container images"

  mapfile -t all_charts < <(sbom_get_charts "${sbom_file}")

  for chart in "${all_charts[@]}"; do
    _add_container_images_for_component "${sbom_file}" "${template_file}" "${chart}"
  done
}

_add_location_for_component() {
  local chart_name chart_version location sbom_file
  sbom_file="${1}"
  chart="${2}"

  chart_name=$(yq ".name" "${chart}")
  chart_version=$(yq ".version" "${chart}")
  location="${chart#"${ROOT}/"}"
  location="${location%/Chart.yaml}"
  query="with(.components[] | select(.name == \"${chart_name}\" and .version == \"${chart_version}\"); .evidence |= (. + $(_format_location_object "${location}")))"
  _yq_run_query "${sbom_file}" "${query}"
}

# adds chart locations for all components in a input sbom file
_add_locations() {
  local chart sbom_file
  sbom_file="${1}"

  log_info "Getting locations"
  mapfile -t all_charts < <(find "${HELMFILE_FOLDER}" -name "Chart.yaml")
  for chart in "${all_charts[@]}"; do
    _add_location_for_component "${sbom_file}" "${chart}"
  done

  # some charts added as dependencies in other charts gets added twice with cdxgen
  # such dependency charts will not always have a location added to them, so we remove them here
  yq -i 'del(.components[] | select(.evidence == null))' "${sbom_file}"
}

# supports removing an entry from the properties field of a sbom component
sbom_remove() {
  if [[ "$#" -ne 2 ]]; then
    usage
  fi

  local location value

  location="${1}"
  value="${2}"

  query="with(.components[] | select(.evidence.occurrences[0].location == \"${location}\").properties; del(.[] | select(.name == \"${value}\")))"

  _yq_run_query "${SBOM_FILE}" "${query}"
  yq -o json -i '.version += 1' "${SBOM_FILE}"
}

sbom_add() {
  if [[ "$#" -lt 3 ]]; then
    usage
  fi

  local location key

  location="${1}"
  key="${2}"

  _sbom_add_component "${SBOM_FILE}" "${@}"
  yq -o json -i '.version += 1' "${SBOM_FILE}"
  log_info "Updated ${key} for ${location}"
}

sbom_get() {
  local key location query sbom_file
  if [[ "$#" -lt 2 ]] || [[ "$#" -gt 3 ]]; then
    usage
  fi

  sbom_file="${1}"
  location="${2}"
  query=".components[] | select(.evidence.occurrences[0].location == \"${location}\")"
  if [[ "$#" -gt 2 ]]; then
    key="${3}"
    query=".components[] | select(.evidence.occurrences[0].location == \"${location}\") | .${key}"
  fi

  yq -e -o json "${query}" "${sbom_file}"
}

sbom_get_unset() {
  output_query=' { "name": .name, "version": .version, "location": .evidence.occurrences[0].location}'

  local licenses=()
  mapfile -t -O "${#licenses[@]}" licenses < <(yq -I=0 -o json -r "[.components[] | select(.licenses[].license.name | contains(\"set-me\")) | ${output_query}] | .[]" "${SBOM_FILE}")
  mapfile -t -O "${#licenses[@]}" licenses < <(yq -I=0 -o json -r "[.components[] | select(.licenses | length == 0) | ${output_query}] | .[]" "${SBOM_FILE}")
  mapfile -t -O "${#licenses[@]}" licenses < <(yq -I=0 -o json -r "[.components[] | select(has(\"licenses\") == \"false\") | ${output_query}] | .[]" "${SBOM_FILE}")
  log_info "Getting components without licenses"
  jq -c <<<"${licenses[@]}"

  echo
  local elastisys_evaluations=()
  mapfile -t -O "${#elastisys_evaluations[@]}" elastisys_evaluations < <(yq -I=0 -o json -r "[.components[] | select(.properties[].value == \"set-me\")  | ${output_query}] | .[]" "${SBOM_FILE}")
  log_info "Getting components without Elastisys evaluation"
  jq -c <<<"${elastisys_evaluations[@]}"

  echo
  local suppliers=()
  log_info "Getting components without supplier"
  mapfile -t -O "${#suppliers[@]}" suppliers < <(yq -I=0 -o json -r "[.components[] | select(.supplier.name == \"set-me\")  | ${output_query}] | .[]" "${SBOM_FILE}")
  jq -c <<<"${suppliers[@]}"

  if [[ "${#licenses[@]}" -gt 0 ]] || [[ "${#elastisys_evaluations[@]}" -gt 0 ]] || [[ "${#suppliers[@]}" -gt 0 ]]; then
    exit 1
  fi
}

sbom_get_charts() {
  local query sbom_file
  sbom_file="${1}"
  query='[.components[] | { "name": .name, "version": .version, "location": .evidence.occurrences[0].location }] | .[]'

  yq -e -o json -I=0 "${query}" "${sbom_file}"
}

sbom_get_containers() {
  local query
  query='.components[] | [.components[] | { "name": .name, "version": .version}] | .[]'

  yq -e -o json --colors -I=0 "${query}" "${SBOM_FILE}" | sort -u
}

sbom_edit() {
  if [[ "$#" -ne 2 ]]; then
    usage
  fi

  local location key

  location="${1}"
  key="${2}"

  _sbom_edit_component "${SBOM_FILE}" "${@}"
  yq -o json -i '.version += 1' "${SBOM_FILE}"
  log_info "Updated ${key} for ${location}"
}

_test_github_token() {
  log_info "Testing GITHUB_TOKEN"
  : "${GITHUB_TOKEN:?Missing GITHUB_TOKEN}"

  # test GITHUB token
  if ! ${CK8S_SKIP_VALIDATION:-}; then
    curl --silent --fail --show-error --output /dev/null \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      "https://api.github.com/repos/elastisys/compliantkubernetes-apps"
  fi
}

sbom_update() {
  local full_path_location location tmp_output_sbom_file tmp_sbom_file
  if [[ "$#" -ne 1 ]]; then
    usage
  fi

  location="${1}"
  full_path_location="${ROOT}/${location}"
  if [[ ! -d "${full_path_location}" ]]; then
    log_fatal "${full_path_location} is not a valid directory"
  fi
  if [[ ! -f "${full_path_location}/Chart.yaml" ]]; then
    log_fatal "${full_path_location} is not a valid Helm chart directory"
  fi

  tmp_sbom_file=$(mktemp --suffix=-update-sbom.json)
  append_trap "rm ${tmp_sbom_file} >/dev/null 2>&1" EXIT

  _test_github_token

  export CK8S_AUTO_APPROVE=true
  export CK8S_SKIP_VALIDATION=true

  _prepare_sbom "${tmp_sbom_file}" --location "${full_path_location}"

  _add_licenses "${tmp_sbom_file}"

  _add_container_images "${tmp_sbom_file}" "${full_path_location}"

  _add_dependencies "${tmp_sbom_file}"

  CK8S_AUTO_APPROVE=false
  CK8S_SKIP_VALIDATION=false

  tmp_output_sbom_file=$(mktemp --suffix=-output-sbom.json)
  append_trap "rm ${tmp_output_sbom_file} >/dev/null 2>&1" EXIT

  # merge components array based on location key
  # query reference: https://mikefarah.gitbook.io/yq/operators/multiply-merge#merge-arrays-of-objects-together-matching-on-a-key
  # shellcheck disable=SC2016
  idPath=".evidence.occurrences[0].location" components=".components" yq eval-all '
  (
    (( .components[] | {(eval(strenv(idPath))):  .}) as $item ireduce ({}; . * $item )) as $uniqueMap
    | ( $uniqueMap  | to_entries | .[]) as $item ireduce([]; . + $item.value)
  ) as $mergedArray
  | select(fi == 0) | (eval(strenv(components))) = $mergedArray
  ' "${SBOM_FILE}" "${tmp_sbom_file}" >"${tmp_output_sbom_file}"

  # when the version changes, the bom-ref gets changed, hence, the dependency for the old version needs to be deleted manually
  old_bom_ref=$(sbom_get "${SBOM_FILE}" "${location}" | jq -r '."bom-ref"')

  # merge old dependency for component with new
  yq -i "with(.dependencies[]; select(.ref == \"${old_bom_ref}\") = load(\"${tmp_sbom_file}\").dependencies[0])" "${tmp_output_sbom_file}"

  sbom_cyclonedx_validation "${tmp_output_sbom_file}"

  diff -U3 --color=always "${SBOM_FILE}" "${tmp_output_sbom_file}" && log_info "No change" && exit 0

  # prompt for manually set elastisys evaluation property
  log_warning "Is the Elastisys evaluation still valid?"
  sbom_get "${tmp_output_sbom_file}" "${location}" "properties"
  log_warning_no_newline "Do you want to continue and edit? (y/N): "
  read -r reply
  if [[ "${reply}" =~ ^[yY]$ ]]; then
    CK8S_AUTO_APPROVE=true _sbom_edit_component "${tmp_output_sbom_file}" "${location}" properties
  fi

  # prompt for manually set supplier
  log_warning "Is the supplier still valid?"
  sbom_get "${tmp_output_sbom_file}" "${location}" "supplier"
  log_warning_no_newline "Do you want to continue and edit? (y/N): "
  read -r reply
  if [[ "${reply}" =~ ^[yY]$ ]]; then
    CK8S_AUTO_APPROVE=true _sbom_edit_component "${tmp_output_sbom_file}" "${location}" supplier
  fi

  # need to delete components and dependencies to not override first element in components array
  yq -i 'del(.components)' "${tmp_sbom_file}"
  yq -i 'del(.dependencies)' "${tmp_sbom_file}"
  # merges with cdxgen template to get timestamp and project version updated
  yq -o json -i eval-all 'select(fileIndex == 0) *d select(fileIndex == 1)' "${tmp_output_sbom_file}" "${tmp_sbom_file}"

  log_warning_no_newline "Do you want to replace SBOM file? (y/N): "
  read -r reply
  if [[ "${reply}" == "y" ]]; then
    mv "${tmp_output_sbom_file}" "${SBOM_FILE}"
    yq -o json -i '.version += 1' "${SBOM_FILE}"
    log_info "SBOM file replaced"
    exit 0
  fi
  log_info "Skipped replacing SBOM"
}

sbom_generate() {
  local tmp_sbom_file
  tmp_sbom_file=$(mktemp --suffix=-generate-sbom.json)
  append_trap "rm ${tmp_sbom_file} >/dev/null 2>&1" EXIT

  _test_github_token

  export CK8S_AUTO_APPROVE=true
  export CK8S_SKIP_VALIDATION=true

  if [[ ! -f "${SBOM_FILE}" ]]; then
    log_info "SBOM file does not exists, creating new"
    touch "${SBOM_FILE}"
  fi

  _prepare_sbom "${tmp_sbom_file}" "${@}"

  _add_licenses "${tmp_sbom_file}"

  _add_container_images "${tmp_sbom_file}"

  _add_dependencies "${tmp_sbom_file}"

  CK8S_AUTO_APPROVE=false
  CK8S_SKIP_VALIDATION=false
  sbom_cyclonedx_validation "${tmp_sbom_file}"

  diff -U3 --color=always "${SBOM_FILE}" "${tmp_sbom_file}" && log_info "No change" && exit 0
  log_warning_no_newline "Do you want to replace SBOM file? (y/N): "
  read -r reply
  if [[ "${reply}" == "y" ]]; then
    mv "${tmp_sbom_file}" "${SBOM_FILE}"
    yq -o json -i '.version += 1' "${SBOM_FILE}"
    log_info "SBOM file replaced"
    exit 0
  fi
  log_info "Skipped replacing SBOM"
}

sbom_diff() {
  local found_diff location
  mapfile -t diff_files < <(git diff --staged --name-only | grep "helmfile.d/")
  mapfile -t all_charts < <(sbom_get_charts "${SBOM_FILE}")

  should_fail=false
  for chart in "${all_charts[@]}"; do
    found_diff=false
    sbom_component_name=$(yq '.name' <<<"${chart}")
    sbom_component_version=$(yq '.version' <<<"${chart}")
    location=$(yq '.location' <<<"${chart}")

    for diff_file in "${diff_files[@]}"; do
      if [[ "${diff_file}" == *${location}* ]]; then
        chart_name="$(yq '.name' "${ROOT}/${location}/Chart.yaml")"
        chart_version="$(yq '.version' "${ROOT}/${location}/Chart.yaml")"
        if [[ "${chart_version}" != "${sbom_component_version}" ]]; then
          found_diff=true
          log_warning "Chart version \"${chart_version}\" does not match SBOM \"${sbom_component_version}\""
          break
        elif [[ "${chart_name}" != "${sbom_component_name}" ]]; then
          found_diff=true
          log_warning "Chart name \"${chart_name}\" does not match SBOM \"${sbom_component_name}\""
          break
        fi
      fi
    done

    if [[ "${found_diff}" == true ]]; then
      should_fail=true
      log_warning "Run the following to update the SBOM:"
      log_warning "./scripts/sbom/sbom.bash update ${location}"
    fi
  done

  if [[ "${should_fail}" == false ]]; then
    log_info "No chart changes found"
  else
    exit 1
  fi
}

if [[ "$#" -lt 1 ]]; then
  usage
fi

case "${1}" in
add)
  shift
  sbom_add "${@}"
  ;;
diff)
  shift
  sbom_diff "${@}"
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
  sbom_get "${SBOM_FILE}" "${@}"
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
update)
  shift
  sbom_update "${@}"
  ;;
validate)
  sbom_cyclonedx_validation "${SBOM_FILE}"
  ;;
*) usage ;;
esac
