#!/usr/bin/env bash

# TODO:
# - grouping management and workload? can potentially have differing container images fpr the same chart
# - dry-run option?
# - trap for removing all sbom files generated in /tmp
# - add cyclonedx & cdxgen to requirements
# - create tests
# - currently, some components might get "set-me"s licenses although they have one set
# - update sbom version per Welkin release

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
# TODO: figure out a different approach for retrieving licenses, or handle GITHUB_TOKEN better
: "${GITHUB_TOKEN:?Missing GITHUB_TOKEN}"

export CK8S_SKIP_VALIDATION="true"

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "${HERE}")"
HELMFILE_FOLDER="${ROOT}/helmfile.d"
SBOM_FILE="${ROOT}/docs/bom.json"
SBOM_TEMPLATE_FILE="${ROOT}/docs/bom.template.json"

# shellcheck source=bin/common.bash
source "${HERE}/common.bash"

usage() {
  echo "Usage:  generate" >&2
  echo "        get-unset" >&2
  echo "        add <component-name> <key> <value>" >&2
  echo "        get <component-name> [key]" >&2
  echo "        remove <component-name> <key> <value>" >&2
  echo "        update <component-name> <key>" >&2
  echo "        validate" >&2
  exit 1
}

# TODO:
# - runtime sbom?
# - build sbom?
# - handle if component not in list?

_yq_update_component_json() {
  local component key sbom_file tmp_sbom_file

  sbom_file="${1}"
  component="${2}"
  key="${3}"

  tmp_sbom_file=$(mktemp --suffix=-sbom.json)
  append_trap "rm ${tmp_sbom_file} >/dev/null 2>&1" EXIT

  tmp_change=$(mktemp --suffix=-update-sbom.json)
  append_trap "rm ${tmp_change} >/dev/null 2>&1" EXIT

  # check if key that should be updated exists
  has_key=$(yq4 -e -o json ".components[] | select(.name == \"${component}\") | has(\"${key}\")" "${sbom_file}")
  if [[ "${has_key}" == false ]]; then
    log_fatal "${key} not found"
  fi

  yq4 -e -o json ".components[] | select(.name == \"${component}\") | .${key}" "${sbom_file}" > "${tmp_change}"
  "${EDITOR}" "${tmp_change}"

  # log_info "here"
  query="with(.components[] | select(.name == \"${component}\"); .${key} = $(jq -c '.' "${tmp_change}"))"
  if ! ${CK8S_AUTO_APPROVE:-}; then
    change=${tmp_change} yq4 -o json "${query}" "${sbom_file}" > "${tmp_sbom_file}"
    cyclonedx_validation "${tmp_sbom_file}"
    diff  -U3 --color=always "${sbom_file}" "${tmp_sbom_file}" && log_info "No change" && return
    log_info "Changes found"
    ask_abort
  fi

  yq4 -i -o json "${query}" "${sbom_file}"
}

_yq_add_component_json() {
  local component key sbom_file tmp_sbom_file value

  sbom_file="${1}"
  component="${2}"
  key="${3}"
  value="${4}"

  tmp_sbom_file=$(mktemp --suffix=-sbom.json)
  append_trap "rm ${tmp_sbom_file} >/dev/null 2>&1" EXIT

  if [[ ! "${key}" =~ ^(licenses.*|properties.*)$ ]]; then
    log_fatal "unsupported key \"${key}\", currently only supports \"licenses|properties\""
  fi

  query="with(.components[] | select(.name == \"${component}\"); .${key} |= (. + ${value} | unique_by(.name)))"
  if ! ${CK8S_AUTO_APPROVE:-}; then
    yq4 -o json "${query}" "${sbom_file}" > "${tmp_sbom_file}"
    cyclonedx_validation "${tmp_sbom_file}"
    diff  -U3 --color=always "${sbom_file}" "${tmp_sbom_file}" && log_info "No change" && return
    log_info "Changes found"
    ask_abort
  fi

  yq4 -i -o json "${query}" "${sbom_file}"
}

# checks if a license is listed as a supported license id
_id_or_name_license() {
  local license="${1}"
  if [[ $(curl --silent https://cyclonedx.org/schema/spdx.schema.json | yq4 -r ".enum | contains([\"${license}\"])" ) == "true" ]]; then
    echo "id"
    return
  fi
  echo "name"
}

_format_license_object() {
  local license="${1}"
  echo "{\"license\": {\"$(_id_or_name_license "${license}")\": \"${license}\"}}"

}

_format_property_object() {
  local name value
  name="${1}"
  value="${2}"
  echo "{\"name\": \"${name}\", \"value\": \"${value}\"}"
}

_format_container_image_object() {
  local container_image="${1}"
  container_image_name=${container_image##*/}
  container_image_name=${container_image_name%%:*}
  _format_property_object "container-${container_image_name}" "${container_image}"
}

_format_elastisys_evaluation_object() {
  local evaluation="${1}"
  _format_property_object "Elastisys evaluation" "${evaluation}"
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

  cdxgen --filter '.*' -t helm "${HELMFILE_FOLDER}" --output "${sbom_file}"

  yq4 -o json -i ". *= load(\"${SBOM_TEMPLATE_FILE}\")" "${sbom_file}"

  mapfile -t components < <(yq4 -r -o json '.components[].name' "${sbom_file}")

  for component in "${components[@]}"; do
    _yq_add_component_json "${sbom_file}" "${component}" "licenses" "[]"
    _yq_add_component_json "${sbom_file}" "${component}" "properties" "[]"
    _yq_add_component_json "${sbom_file}" "${component}" "properties" "$(_format_elastisys_evaluation_object "set-me")"
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
  mapfile -t charts < <(find "${HELMFILE_FOLDER}/upstream" -name "Chart.yaml")

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")

    # check if chart.yaml contains license in annotations
    annotation=$(yq4 ".annotations.licenses" "${chart}")
    annotation_artifacthub=$(yq4 ".annotations.artifacthub.io/license" "${chart}")

    if [[ -n "${annotation}" && "${annotation}" != "null" ]]; then
      _yq_add_component_json "${sbom_file}" "${chart_name}" "licenses" "$(_format_license_object "${annotation}")"

    elif [[ -n "${annotation_artifacthub}" && "${annotation_artifacthub}" != "null" ]]; then
      _yq_add_component_json "${sbom_file}" "${chart_name}" "licenses" "$(_format_license_object "${annotation_artifacthub}")"

    # if no license in annotations, try to get from source (e.g. github)
    else
      # TODO: handle multiple licenses, or, stick with one
      mapfile -t sources < <(yq4 '.sources[]' "${chart}")
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
               _yq_add_component_json "${sbom_file}" "${chart_name}" "licenses" "$(_format_license_object "${l}")"
            done
          fi
        done
      fi
    fi
  done

  # Welkin charts
  mapfile -t charts < <(find "${HELMFILE_FOLDER}/charts" -name "Chart.yaml")

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")

    # TODO: licenses for the applications
    _yq_add_component_json "${sbom_file}" "${chart_name}" "licenses" "$(_format_license_object "Apache-2.0")"
  done
}

_get_container_images_helmfile_template() {
  local sbom_file helmfile_template_file chart_name release_name type
  sbom_file="${1}"
  helmfile_template_file="${2}"
  chart_name="${3}"
  log_info "${chart_name}"
  release_name="${4}"
  type="${5}"

  local sbom_file
  if [[ "$#" -ne 4 ]]; then
    log_fatal "usage: _get_container_images_helmfile_template <sbom-file> <helmfile-template-file> <chart_name> <release_name> <type>"
  fi

  chart_query=".metadata.labels.\"helm.sh/chart\" | contains(\"${chart_name}\")"

  if [[ "${type}" == "pod" ]]; then
    query="select(.kind == \"Pod\" and ${chart_query}) | .spec.containers[] | .image"
  elif [[ "${type}" == "cronjob" ]]; then
    query="select(.kind == \"CronJob\" and ${chart_query})) | .spec.jobTemplate.spec.template.spec.containers[] | .image"
  elif [[ "${type}" == "daemonset" ]]; then
    query="select(.kind == \"DaemonSet\" and ${chart_query})) | .spec.template.spec.containers[] | .image"
  elif [[ "${type}" == "deployment" ]]; then
    query="select(.kind == \"Deployment\" and ${chart_query})) | .spec.template.spec.containers[] | .image"
  elif [[ "${type}" == "job" ]]; then
    query="select(.kind == \"Job\" and ${chart_query})) | .spec.template.spec.containers[] | .image"
  elif [[ "${type}" == "statefulset" ]]; then
    query="select(.kind == \"StateFulset\" and ${chart_query})) | .spec.template.spec.containers[] | .image"
  fi

  export CK8S_SKIP_VALIDATION=true
  export CK8S_AUTO_APPROVE=true
  mapfile -t containers < <(yq4 "${query}" "${helmfile_template_file}" | sed '/---/d' | sort -u)

  if [[ ${#containers[@]} -eq 0 ]]; then
    # Although these contains e.g. prometheus-node-exporter which we run but through kube-prometheus-stack
    # Maybe add a check for sub-charts that are part of umbrella charts?
    return
  fi

  for container in "${containers[@]}"; do
    _yq_add_component_json "${sbom_file}" "${chart_name}" "properties" "$(_format_container_image_object "${container}")"
  done
}


# _get_pods_container_images() {
#   local sbom_file chart_name release_name release_namespace
#   sbom_file="${1}"
#   chart_name="${2}"
#   release_name="${3}"
#   release_namespace="${4}"

#   local sbom_file
#   if [[ "$#" -ne 4 ]]; then
#     log_fatal "usage: _get_pods_container_images <sbom-file> <chart_name> <release_name> <release_namespace>"
#   fi

#   mapfile -t containers < <("${HERE}/ops.bash" kubectl sc get pods \
#     --selector app.kubernetes.io/instance="${release_name}" \
#     --namespace "${release_namespace}" \
#     -oyaml | yq4 '.items[] | .spec.containers[] | .image' | sort -u)

#   if [[ ${#containers[@]} -eq 0 ]]; then
#     # Although these contains e.g. prometheus-node-exporter which we run but through kube-prometheus-stack
#     # Maybe add a check for sub-charts that are part of umbrella charts?
#     return
#   fi

#   for container in "${containers[@]}"; do
#     _yq_add_component_json "${sbom_file}" "${chart_name}" "properties" "$(_format_container_image_object "${container}")"
#   done
# }

_get_container_images() {
  local sbom_file
  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: _get_container_images <sbom-file>"
  fi

  sbom_file="${1}"
  if [[ ! -f "${sbom_file}" ]]; then
    log_fatal "SBOM file ${sbom_file} does not exist"
  fi

  helmfile_template_file=$(mktemp --suffix helmfile_template_file)

  log_info "Getting container images"

  mapfile -t charts < <(find "${HELMFILE_FOLDER}" -name "Chart.yaml")

  # TODO:
  # - what about wc? this should list all charts in both wc/sc, but should only those enabled/installed=true be checked?
  helmfile_list=$("${HERE}/ops.bash" helmfile sc list --output json)
  "${HERE}/ops.bash" helmfile sc template 2> /dev/null > "${helmfile_template_file}"
  "${HERE}/ops.bash" helmfile wc template 2> /dev/null >> "${helmfile_template_file}"

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")
    chart_folder_name="${chart#"${HELMFILE_FOLDER}/"}"
    chart_folder_name="${chart_folder_name%\/Chart.yaml}"

    mapfile -t releases < <(echo "${helmfile_list}" | jq -c ".[] | select(.chart == \"${chart_folder_name}\")")

    if [[ ${#releases[@]} -eq 0 ]]; then
      # log_warning "no releases for $chart_name"
      # Maybe add a check for sub-charts that are part of umbrella charts e.g. prometheus-node-exporter?
      continue
    fi

    for release in "${releases[@]}"; do
      release_name=$(echo "${release}" | jq -r ".name")
      _get_container_images_helmfile_template "${sbom_file}" "${helmfile_template_file}" "${chart_name}" "${release_name}" "cronjob"
      _get_container_images_helmfile_template "${sbom_file}" "${helmfile_template_file}" "${chart_name}" "${release_name}" "pod"
      _get_container_images_helmfile_template "${sbom_file}" "${helmfile_template_file}" "${chart_name}" "${release_name}" "deployment"
      _get_container_images_helmfile_template "${sbom_file}" "${helmfile_template_file}" "${chart_name}" "${release_name}" "job"
      _get_container_images_helmfile_template "${sbom_file}" "${helmfile_template_file}" "${chart_name}" "${release_name}" "daemonset"
      _get_container_images_helmfile_template "${sbom_file}" "${helmfile_template_file}" "${chart_name}" "${release_name}" "statefulset"
    done

    # TODO: mapping chart names to release names?
    # - e.g. for Thanos, we deploy all components from same chart but as separate releases
  done
}

cyclonedx_validation() {
  local sbom_file

  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: cyclonedx_validation <sbom-file>"
  fi

  sbom_file="${1}"
  if [[ ! -f "${sbom_file}" ]]; then
    log_fatal "SBOM file ${sbom_file} does not exist"
  fi

  log_info "Validating CycloneDX for SBOM file"
  cyclonedx validate --fail-on-errors --input-file "${sbom_file}" && true; exit_code="$?"
  if ! ${CK8S_AUTO_APPROVE:-} && [[ "${exit_code}" != 0 ]]; then
    log_warning_no_newline "CycloneDX Validation failed, do you want to continue anyway? (y/N): "
    read -r reply
    if [[ "${reply}" == "n" ]]; then
      exit 0
    fi
  fi
}

get_unset() {
  log_info "Getting components without licenses"
  yq4 -o json -r '.components[] | select(.licenses[].license.name | contains("set-me")).name' "${SBOM_FILE}"
  yq4 -o json -r '.components[] | select(.licenses | length == 0).name' "${SBOM_FILE}"
  log_info "Getting components without containers"
  yq4 -o json -r '.components[] | select(.properties[].name | contains("set-me")).name' "${SBOM_FILE}"
  log_info "Getting components without Elastisys evaluation"
  yq4 -o json -r '.components[] | select(.properties[].value | contains("set-me")).name' "${SBOM_FILE}"
}

sbom_remove() {
  log_info "TODO:"
}

sbom_add() {
  if [[ "$#" -ne 3 ]]; then
    usage
  fi

  local component key

  component="${1}"
  key="${2}"

  _yq_add_component_json "${SBOM_FILE}" "${@}"
  log_info "Updated ${key} for ${component}"
}

sbom_get() {
  if [[ "$#" -lt 1 ]]; then
    usage
  fi

  local component key

  component="${1}"
  query=".components[] | select(.name ==\"${component}\")"
  # key="${2}"
  if [[ "$#" -gt 1 ]]; then
    key="${2}"
    query=".components[] | select(.name ==\"${component}\") | .${key}"
  fi

  yq4 -e -o json "${query}" "${SBOM_FILE}"
}

sbom_update() {
  if [[ "$#" -ne 2 ]]; then
    usage
  fi

  local component key

  component="${1}"
  key="${2}"

  _yq_update_component_json "${SBOM_FILE}" "${@}"
  log_info "Updated ${key} for ${component}"
}

sbom_generate() {
  local tmp_sbom_file
  tmp_sbom_file=$(mktemp --suffix=-sbom.json)
  append_trap "rm ${tmp_sbom_file} >/dev/null 2>&1" EXIT

  export CK8S_AUTO_APPROVE=true

  if [[ ! -f "${SBOM_FILE}" ]]; then
    log_info "SBOM file does not exists, creating new"
    touch "${SBOM_FILE}"
  fi

  _prepare_sbom "${tmp_sbom_file}"

  # TODO: (maybe) loop over charts here, and retrieve necessary info per chart (would reduce number of for loops)
  _get_licenses "${tmp_sbom_file}"

  _get_container_images "${tmp_sbom_file}"

  cyclonedx_validation "${tmp_sbom_file}"

  diff  -U3 --color=always "${SBOM_FILE}" "${tmp_sbom_file}" && return
  log_warning_no_newline "Do you want to replace SBOM file? (y/N): "
  read -r reply
  if [[ "${reply}" == "y" ]]; then
    mv "${tmp_sbom_file}" "${SBOM_FILE}"
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
generate)
  shift
  sbom_generate "${@}"
  ;;
get)
  shift
  sbom_get "${@}"
  ;;
get-unset)
  shift
  get_unset "${@}"
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
  cyclonedx_validation "${SBOM_FILE}"
  ;;
*) usage ;;
esac
