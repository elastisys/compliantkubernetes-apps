#!/usr/bin/env bash

# TODO:
# - grouping management and workload? can potentially have differing container images fpr the same chart

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

export CK8S_SKIP_VALIDATION="true"

here="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
root="$(dirname "${here}")"
helmfile_folder="${root}/helmfile.d"
sbom_file="${root}/docs/bom.json"

# shellcheck source=bin/common.bash
source "${here}/common.bash"

# TODO:
# - add containers per chart
# - include license (try to implement, but should be able to be set manually)
# -

usage() {
  echo "Usage:  generate" >&2
  echo "        add <component-name> <key> <value>" >&2
  exit 1
}

# TODO:
# - runtime sbom?
# - build sbom?

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
  mapfile -t charts < <(find "${helmfile_folder}/upstream" -name "Chart.yaml")

  for chart in "${charts[@]}"; do
    licenses=()
    chart_name=$(yq4 ".name" "${chart}")

    # TODO: figure out licenses
    annotation=$(yq4 ".annotations.licenses" "${chart}")
    annotation_artifacthub=$(yq4 ".annotations.artifacthub.io/license" "${chart}")
    if [[ -n "${annotation}" && "${annotation}" != "null" ]]; then
      licenses+=("${annotation}")
    elif [[ -n "${annotation_artifacthub}" && "${annotation_artifacthub}" != "null" ]]; then
      licenses+=("${annotation_artifacthub}")
    else
      licenses+=("set-me")
      # TODO: handle multiple licenses, or, stick with one
      # mapfile -t sources < <(yq4 '.sources[]' "${chart}")

      # for source in "${sources[@]}"; do
      #   repo=${source##*github.com/}
      #   echo "repo: $repo"

      #   # API rate limits :grimacing:
      #   mapfile -t licenses_in_git < <(curl -L -s \
      #     -H "Accept: application/vnd.github+json" \
      #     -H "X-GitHub-Api-Version: 2022-11-28" \
      #     "https://api.github.com/repos/${repo}" | jq -r '.license.name')

      #   for l in "${licenses_in_git[@]}"; do
      #     licenses+=( "${l}" )
      #   done
      # done
    fi

    sbom_add "${chart_name}" "licenses[]" "${licenses[@]}"
  done

  # Welkin charts
  mapfile -t charts < <(find "${helmfile_folder}/charts" -name "Chart.yaml")

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")

    # TODO: licenses for the applications
    sbom_add "${chart_name}" "licenses[0].id" "Apache-2.0"
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

  mapfile -t charts < <(find "${helmfile_folder}/upstream" -name "Chart.yaml")

  helmfile_list=$("${here}/ops.bash" helmfile sc list --output json)

  # echo "${helmfile_list}" | jq

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")
    chart_folder_name="${chart#"${helmfile_folder}/"}"
    chart_folder_name="${chart_folder_name%\/Chart.yaml}"

    # release=$(echo "${helmfile_list}" | jq ".[] | select(.chart == \"${chart_folder_name}\")")
    mapfile -t releases < <(echo "${helmfile_list}" | jq -c ".[] | select(.chart == \"${chart_folder_name}\")")

    if [[ ${#releases[@]} -eq 0 ]]; then

      log_warning "no releases for $chart_name"
      # TODO: remove these from sbom?
      # Although these contains e.g. prometheus-node-exporter which we run but through kube-prometheus-stack
      # Maybe add a check for sub-charts that are part of umbrella charts?
      sbom_add "${chart_name}" "containers[]" "[]"
      continue
    fi

    for release in "${releases[@]}"; do
      release_name=$(echo "${release}" | jq -r ".name")
      # TODO: what if a chart deploys pods in different namespace then release?
      release_namespace=$(echo "${release}" | jq -r ".namespace")
      mapfile -t containers < <("${here}/ops.bash" kubectl sc get pods \
        --selector app.kubernetes.io/instance="${release_name}" \
        --namespace "${release_namespace}" \
        -oyaml | yq4 '.items[] | .spec.containers[] | .image' | sort -u)
      if [[ ${#containers[@]} -eq 0 ]]; then
        log_warning "no containers for release $release_name"
        # TODO: remove these from sbom?
        # Although these contains e.g. prometheus-node-exporter which we run but through kube-prometheus-stack
        # Maybe add a check for sub-charts that are part of umbrella charts?
        sbom_add "${chart_name}" "containers[]" "[]"
        continue
      fi
      echo sbom_add "${chart_name}" "containers" "${containers[@]}"
      sbom_add "${chart_name}" "containers[]" "${containers[@]}"
    done

    # TODO: mapping chart names to release names?
    # - e.g. for Thanos, we deploy all components from same chart but as separate releases
  done
}

sbom_remove() {
  log_info "TODO:"
}

sbom_add() {
  # TODO:
  # - only support for certain "keys" per component
  # - error handling if component does not exist
  # - add dry-run option
  if [[ "$#" -lt 3 ]]; then
    usage
  fi

  component="${1}"
  key="${2}"
  shift 2
  values=("${@}")

  # if [[ ! "${key}" =~ ^(licenses|containers)$ ]]; then
  #   log_fatal "unsupported key, currently only supports \"licenses|containers\""
  # fi

  for value in "${values[@]}"; do
    yq4 -e -i -o json "(.components[] | select(.name == \"${component}\") | .${key}) |= \"${value}\"" "${sbom_file}"
  done
}

sbom_generate() {
  # TODO:
  # check/compare existing bom.json file?
  tmp_sbom_file=$(mktemp --suffix=sbom)
  if [[ ! -f "${sbom_file}" ]]; then
    log_info "SBOM file does not exists, creating new"
    tmp_sbom_file="${sbom_file}"
  fi
  # create in /tmp and then compare
  cdxgen -t helm --recurse "${helmfile_folder}" --output "${tmp_sbom_file}"

  _get_license "${tmp_sbom_file}"

  _get_container_images "${tmp_sbom_file}"

  # TODO: check if diff, prompt if replace or something
  diff  -U3 --color=always "${sbom_file}" "${tmp_sbom_file}" && return

  log_warning_no_newline "Do you want to replace SBOM file? (y/N): "
  read -r reply
  if [[ "${reply}" == "y" ]]; then
    mv "${tmp_sbom_file}" "${sbom_file}"
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
remove)
  shift
  sbom_remove "${@}"
  ;;
*) usage ;;
esac
