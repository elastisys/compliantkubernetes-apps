#!/usr/bin/env bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"
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
    license=()
    chart_name=$(yq4 ".name" "${chart}")

    # TODO: figure out license
    annotation=$(yq4 ".annotations.licenses" "${chart}")
    annotation_artifacthub=$(yq4 ".annotations.artifacthub.io/license" "${chart}")
    if [[ -n "${annotation}" && "${annotation}" != "null" ]]; then
      license+=("${annotation}")
    elif [[ -n "${annotation_artifacthub}" && "${annotation_artifacthub}" != "null" ]]; then
      license+=("${annotation_artifacthub}")
    else
      license+=("set-me")
      # TODO: handle multiple licenses, or, stick with one
      # mapfile -t sources < <(yq4 '.sources[]' "${chart}")

      # for source in "${sources[@]}"; do
      #   repo=${source##*github.com/}
      #   echo "repo: $repo"

      #   # API rate limits :grimacing:
      #   mapfile -t licenses < <(curl -L -s \
      #     -H "Accept: application/vnd.github+json" \
      #     -H "X-GitHub-Api-Version: 2022-11-28" \
      #     "https://api.github.com/repos/${repo}" | jq -r '.license.name')

      #   for l in "${licenses[@]}"; do
      #     license+=( "${l}" )
      #   done
      # done
    fi

    sbom_add "${chart_name}" "license" "${license[*]}"
  done

  # Welkin charts
  mapfile -t charts < <(find "${helmfile_folder}/charts" -name "Chart.yaml")

  for chart in "${charts[@]}"; do
    chart_name=$(yq4 ".name" "${chart}")

    # TODO: licenses for the applications
    sbom_add "${chart_name}" "license" "Apache-2.0"
  done
}

sbom_remove() {
  log_info "TODO:"
}

sbom_add() {
  # TODO:
  # - only support for certain "keys" per component
  # - error handling if component does not exist
  if [[ "$#" -ne 3 ]]; then
    usage
  fi

  component="${1}"
  key="${2}"
  value="${3}"

  yq4 -e -i -ojson "(.components[] | select(.name == \"${component}\") | .${key}) |= \"${value}\"" "${sbom_file}"
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

  # TODO: check if diff, prompt if replace or something
  diff "${tmp_sbom_file}" "${sbom_file}"
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
