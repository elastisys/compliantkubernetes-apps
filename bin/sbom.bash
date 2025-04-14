#!/usr/bin/env bash

# TODO:
# - grouping management and workload? can potentially have differing container images fpr the same chart
# - clean up tmp files
# - checker for "set-me"s
# - dry-run option?
# - trap for removing all sbom files generated in /tmp
# - cyclonedx validateion (e.g. cyclonedx validate --input-file docs/bom.json)
# - add cyclonedx & cdxgen to requirements
# - create tests

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
# TODO: figure out a different approach for retrieving licenses, or handle GITHUB_TOKEN better
: "${GITHUB_TOKEN:?Missing GITHUB_TOKEN}"

export CK8S_SKIP_VALIDATION="true"

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(dirname "${HERE}")"
HELMFILE_FOLDER="${ROOT}/helmfile.d"
SBOM_FILE="${ROOT}/docs/bom.json"

# shellcheck source=bin/common.bash
source "${HERE}/common.bash"

usage() {
  echo "Usage:  generate" >&2
  echo "        get-unset" >&2
  echo "        add <component-name> <key> <value>" >&2
  echo "        remove <component-name> <key> <value>" >&2
  exit 1
}

# TODO:
# - runtime sbom?
# - build sbom?

_yq_add_json() {
  local component key sbom_file tmp_sbom_file value

  sbom_file="${1}"
  component="${2}"
  key="${3}"
  value="${4}"

  tmp_sbom_file=$(mktemp --suffix=-sbom.json)

  if [[ ! "${key}" =~ ^(licenses.*|properties.*)$ ]]; then
    log_fatal "unsupported key \"${key}\", currently only supports \"licenses|properties\""
  fi

  if ! ${CK8S_AUTO_APPROVE:-}; then
    yq4 -o json "(.components[] | select(.name == \"${component}\") | .${key}) |= ${value}" "${sbom_file}" > "${tmp_sbom_file}"
    cyclonedx validate --input-file "${tmp_sbom_file}"
    diff  -U3 --color=always "${sbom_file}" "${tmp_sbom_file}" && log_info "No change" && return
    log_info "Changes found"
    ask_abort
  fi

  yq4 -i -o json "(.components[] | select(.name == \"${component}\") | .${key}) |= ${value}" "${sbom_file}"
}

# checks if
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

_format_container_image_object() {
  local container_image="${1}"
  echo "{\"name\": \"container\", \"value\": \"${container_image}\"}"
}

_get_license() {
  local sbom_file
  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: _get_license <sbom-file>"
  fi

  sbom_file="${1}"
  if [[ ! -f "${sbom_file}" ]]; then
    log_fatal "SBOM file ${sbom_file} does not exist"
  fi
  log_info "Getting licenses"

  # Upstream charts
  # TODO: make this global since it is used in several functions
  # TODO: filter out unused charts before processing?
  mapfile -t charts < <(find "${HELMFILE_FOLDER}/upstream" -name "Chart.yaml")

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")

    licenses=$(mktemp --suffix="${chart_name}-sbom-licenses.json")
    echo "[]" > "${licenses}"

    # check if chart.yaml contains license in annotations
    annotation=$(yq4 ".annotations.licenses" "${chart}")
    annotation_artifacthub=$(yq4 ".annotations.artifacthub.io/license" "${chart}")

    if [[ -n "${annotation}" && "${annotation}" != "null" ]]; then
      yq4 -o json -i ". + $(_format_license_object "${annotation}")" "${licenses}"

    elif [[ -n "${annotation_artifacthub}" && "${annotation_artifacthub}" != "null" ]]; then
      yq4 -o json -i ". + $(_format_license_object "${annotation_artifacthub}")" "${licenses}"

    # if no license in annotations, try to get from source (e.g. github)
    else
      # TODO: handle multiple licenses, or, stick with one
      mapfile -t sources < <(yq4 '.sources[]' "${chart}")
      if [[ "${#sources[@]}" -eq 0 ]] || [[ "${sources[*]}" == "null" ]]; then
        yq4 -o json -i ". + $(_format_license_object "set-me")" "${licenses}"
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
            yq4 -o json -i ". + $(_format_license_object "set-me")" "${licenses}"
          else
            for l in "${licenses_in_git[@]}"; do
              yq4 -o json -i ". + $(_format_license_object "${l}")" "${licenses}"
            done
          fi
        done
      fi
    fi
    _yq_add_json "${sbom_file}" "${chart_name}" "licenses" "$(jq -c 'unique' "${licenses}")"
  done

  # Welkin charts
  mapfile -t charts < <(find "${HELMFILE_FOLDER}/charts" -name "Chart.yaml")

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")

    # TODO: licenses for the applications
    _yq_add_json "${sbom_file}" "${chart_name}" "licenses[0]" "$(_format_license_object "Apache-2.0")"
  done
}

_get_container_images() {
  local sbom_file
  if [[ "$#" -ne 1 ]]; then
    log_fatal "usage: _get_license <sbom-file>"
  fi

  sbom_file="${1}"
  if [[ ! -f "${sbom_file}" ]]; then
    log_fatal "SBOM file ${sbom_file} does not exist"
  fi
  log_info "Getting container images"

  mapfile -t charts < <(find "${HELMFILE_FOLDER}" -name "Chart.yaml")

  # TODO:
  # - what about wc? this should list all charts in both wc/sc, but should only those enabled/installed=true be checked?
  helmfile_list=$("${HERE}/ops.bash" helmfile sc list --output json)

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")
    chart_folder_name="${chart#"${HELMFILE_FOLDER}/"}"
    chart_folder_name="${chart_folder_name%\/Chart.yaml}"

    # _yq_add_json "${sbom_file}" "${chart_name}" "properties" "[]"
    containers_file=$(mktemp --suffix="${chart_name}-sbom-containers.json")
    echo "[]" > "${containers_file}"

    mapfile -t releases < <(echo "${helmfile_list}" | jq -c ".[] | select(.chart == \"${chart_folder_name}\")")

    if [[ ${#releases[@]} -eq 0 ]]; then
      # log_warning "no releases for $chart_name"
      # Maybe add a check for sub-charts that are part of umbrella charts e.g. prometheus-node-exporter?
      continue
    fi

    for release in "${releases[@]}"; do
      release_name=$(echo "${release}" | jq -r ".name")
      # TODO: what if a chart deploys pods in different namespace then release?
      release_namespace=$(echo "${release}" | jq -r ".namespace")
      # TODO: pods created by operators e.g. scan-vulnerability job?
      # TODO: jobs/cronjobs
      # TODO: what about things disabled by default, e.g. Kured?
      mapfile -t containers < <("${HERE}/ops.bash" kubectl sc get pods \
        --selector app.kubernetes.io/instance="${release_name}" \
        --namespace "${release_namespace}" \
        -oyaml | yq4 '.items[] | .spec.containers[] | .image' | sort -u)

      if [[ ${#containers[@]} -eq 0 ]]; then
        # log_warning "no containers for release $release_name"
        # TODO: remove these from sbom?
        # Although these contains e.g. prometheus-node-exporter which we run but through kube-prometheus-stack
        # Maybe add a check for sub-charts that are part of umbrella charts?
        continue
      fi

      for container in "${containers[@]}"; do
        # TODO: fix only unique container images
        # yq4 -e -i -o json "(.components[] | select(.name == \"${chart_name}\") | .containers) += \"${container}\"" "${sbom_file}"
        yq4 -o json -i ". + $(_format_container_image_object "${container}")" "${containers_file}"
      done
      _yq_add_json "${sbom_file}" "${chart_name}" "properties" "$(jq -c 'unique' "${containers_file}")"
    done

    # TODO: mapping chart names to release names?
    # - e.g. for Thanos, we deploy all components from same chart but as separate releases
  done
}


get_unset() {
  log_info "Getting components without licenses"
  yq4 -o json -r ".components[] | select(.licenses | contains([\"set-me\"])).name" "${sbom_file}"
  log_info "Getting components without containers"
  yq4 -o json -r ".components[] | select(.containers | contains([\"set-me\"])).name" "${sbom_file}"
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

  _yq_add_json "${SBOM_FILE}" "${@}"
  log_info "Updated ${key} for ${component}"
}

sbom_generate() {
  local tmp_sbom_file
  tmp_sbom_file=$(mktemp --suffix=-sbom.json)
  # append_trap "rm /tmp/*sbom*.json" EXIT

  export CK8S_AUTO_APPROVE=true

  # TODO:
  # check/compare existing bom.json file?
  if [[ ! -f "${SBOM_FILE}" ]]; then
    log_info "SBOM file does not exists, creating new"
    touch "${SBOM_FILE}"
  fi
  # create in /tmp and then compare
  cdxgen -t helm --recurse "${HELMFILE_FOLDER}" --output "${tmp_sbom_file}"

  _get_license "${tmp_sbom_file}"

  _get_container_images "${tmp_sbom_file}"
  cyclonedx validate --fail-on-errors --input-file "${tmp_sbom_file}" && true; exit_code="$?"
  if [[ "${exit_code}" != 0 ]]; then
    log_warning_no_newline "CycloneDX Validation failed, do you want to continue anyway? (y/N): "
    read -r reply
    if [[ "${reply}" == "n" ]]; then
      exit 0
    fi
  fi

  diff  -U3 --color=always "${SBOM_FILE}" "${tmp_sbom_file}" && return
  log_warning_no_newline "Do you want to replace SBOM file? (y/N): "
  read -r reply
  if [[ "${reply}" == "y" ]]; then
    mv "${tmp_sbom_file}" "${SBOM_FILE}"
    log_info "SBOM file replaced"
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
get-unset)
  shift
  get_unset "${@}"
  ;;
remove)
  shift
  sbom_remove "${@}"
  ;;
*) usage ;;
esac
