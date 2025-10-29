#!/bin/bash
set -euo pipefail

# --- Input Validation and Configuration ---
if [ "${#}" -ne 1 ]; then
  echo "Usage: $0 <UPSTREAM_CHART_PATH>"
  echo "Example (All Charts): $0 ./helmfile.d/upstream"
  echo "Example (Single Chart): $0 ./helmfile.d/upstream/grafana/grafana"
  exit 1
fi

INPUT_PATH="${1}"
IMAGES_YAML_PATH="./helmfile.d/lists/images.yaml"
IMAGE_MAP_FILE="./tests/unit/general/resources/images-parametric-tests.json"

if [ ! -f "${IMAGE_MAP_FILE}" ]; then
  echo "ERROR: Mapping file '${IMAGE_MAP_FILE}' not found. Please ensure it is in the same directory."
  exit 1
fi

update_images_yaml_tag() {
  local key="{$1}"
  local current_ref="{$2}"
  local new_tag="{$3}"

  local repo="${current_ref%:*}"
  local updated="${repo}:${new_tag}"
  # shellcheck disable=SC2016
  yq -i ".images.${key} = \"${updated}\"" "${IMAGES_YAML_PATH}"
  echo "UPDATED: images.yaml -> .images.${key} = ${updated}"
}

# --- Determine Scope (Single Chart or All Charts) and Calculate Base Directory ---
LAST_PATH_COMPONENT=$(basename "${INPUT_PATH}")
CHART_FILTER=""
UPSTREAM_BASE_DIR=""

if [ -f "${INPUT_PATH}/values.yaml" ]; then
  # Single Chart Mode: Calculate UPSTREAM_BASE_DIR
  CHECK_SCOPE="Single Chart: ${LAST_PATH_COMPONENT}"
  CHART_FILTER="${LAST_PATH_COMPONENT}"

  readarray -t _MAP_OBJECTS < <(jq -c '.parameters[]' "${IMAGE_MAP_FILE}")
  for MAP_OBJECT in "${_MAP_OBJECTS[@]}"; do
    CHART_PATH=$(echo "${MAP_OBJECT}" | jq -r '.drift_chartpath // empty')

    if [ -z "${CHART_PATH}" ]; then continue; fi
    CHART_NAME=$(basename "${CHART_PATH}")

    if [ "${CHART_NAME}" = "${CHART_FILTER}" ] && [[ "${INPUT_PATH}" =~ /${CHART_PATH}$ ]]; then
      UPSTREAM_BASE_DIR="${INPUT_PATH/%${CHART_PATH}/}"
      break
    fi
  done

  if [ -z "${UPSTREAM_BASE_DIR}" ]; then
    echo "ERROR: Could not find a matching chart entry for input path '${INPUT_PATH}'."
    exit 1
  fi
else
  # All Charts Mode
  CHECK_SCOPE="All Charts in Base Dir"
  UPSTREAM_BASE_DIR="${INPUT_PATH%/}/"
fi

echo "--- Starting Image Drift Check ---"
echo "Scope: ${CHECK_SCOPE}"

# Loop through all mappings (array elements)
readarray -t _ALL_MAP_OBJECTS < <(jq -c '.parameters[]' "${IMAGE_MAP_FILE}")
for MAP_OBJECT in "${_ALL_MAP_OBJECTS[@]}"; do

  KEY=$(echo "${MAP_OBJECT}" | jq -r '.image_property')
  CHART_PATH=$(echo "${MAP_OBJECT}" | jq -r '.drift_chartpath // empty')
  TAG_SOURCE_TYPE=$(echo "${MAP_OBJECT}" | jq -r '.drift_tagsourcetype // empty')
  UPSTREAM_PATH=$(echo "${MAP_OBJECT}" | jq -r '.drift_tagpath // ""')

  # Skip entries missing drift configuration
  if [ -z "${CHART_PATH}" ] || [ -z "${TAG_SOURCE_TYPE}" ]; then
    continue
  fi

  CHART_NAME=$(basename "${CHART_PATH}")

  # --- Umbrella Chart Filtering ---
  if [ -n "${CHART_FILTER}" ]; then
    if [ "${CHART_NAME}" != "${CHART_FILTER}" ] && [[ "${CHART_PATH}" != *"${CHART_FILTER}"* ]]; then
      continue
    fi
  fi

  # --- File Path Assembly ---
  UPSTREAM_VALUES_FILE="${UPSTREAM_BASE_DIR}${CHART_PATH}/values.yaml"
  UPSTREAM_CHART_FILE="${UPSTREAM_BASE_DIR}${CHART_PATH}/Chart.yaml"

  # --- Fetch Local Image Details ---
  LOCAL_FULL_IMAGE=$(yq ".images.${KEY}" "${IMAGES_YAML_PATH}" 2>/dev/null)

  if [ "${LOCAL_FULL_IMAGE}" = "null" ]; then
    echo "WARN: Local image key '${KEY}' not found in ${IMAGES_YAML_PATH}. Skipping."
    continue
  fi

  LOCAL_TAG=$(echo "${LOCAL_FULL_IMAGE}" | awk -F '[:@]' '{print $NF}')
  LOCAL_TAG_RAW=$(echo "${LOCAL_FULL_IMAGE}" | awk -F '[:@]' '{print $NF}')

  LOCAL_TAG_NORMALIZED="${LOCAL_TAG#[vV]}"

  SOURCE_FILE_INFO=""

  if [ "${TAG_SOURCE_TYPE}" = "chart.yaml" ]; then
    if [ ! -f "${UPSTREAM_CHART_FILE}" ]; then
      echo "ERROR: Upstream Chart.yaml file not found: '${UPSTREAM_CHART_FILE}' for chart '${CHART_PATH}'. Skipping check for '${KEY}'."
      continue
    fi

    RAW_UPSTREAM_TAG=$(yq ".appVersion" "${UPSTREAM_CHART_FILE}" 2>/dev/null | tr -d '"')
    SOURCE_FILE_INFO="Chart.yaml (AppVersion)"

  elif [ "${TAG_SOURCE_TYPE}" = "values.yaml" ]; then

    if [ ! -f "${UPSTREAM_VALUES_FILE}" ]; then
      echo "ERROR: Upstream values file not found: '${UPSTREAM_VALUES_FILE}' for chart '${CHART_PATH}'. Skipping check for '${KEY}'."
      continue
    fi

    if [ -z "${UPSTREAM_PATH}" ]; then
      echo "ERROR: 'drift_tagpath' is required when 'drift_tagsourcetype' is 'values.yaml' for key '${KEY}'. Skipping."
      continue
    fi

    RAW_UPSTREAM_TAG=$(yq "${UPSTREAM_PATH}" "${UPSTREAM_VALUES_FILE}" 2>/dev/null | tr -d '"')
    SOURCE_FILE_INFO="values.yaml (${UPSTREAM_PATH})"

    if [ -z "${RAW_UPSTREAM_TAG}" ] || [ "${RAW_UPSTREAM_TAG}" = "null" ]; then
      echo "WARN: Chart '${CHART_PATH}' - Path '${UPSTREAM_PATH}' in values.yaml returned empty/null tag. Skipping check for '${KEY}'."
      continue
    fi

  else
    echo "ERROR: Unknown tagSourceType '${TAG_SOURCE_TYPE}' for key '${KEY}'. Skipping."
    continue
  fi

  UPSTREAM_TAG_NORMALIZED="${RAW_UPSTREAM_TAG#[vV]}"

  if [ "${LOCAL_TAG_NORMALIZED}" != "${UPSTREAM_TAG_NORMALIZED}" ]; then
    echo "DRIFT DETECTED for ${KEY} (Chart Path: ${CHART_PATH})"
    echo "  Local version(images.yaml):    ${LOCAL_TAG_NORMALIZED}"
    echo "  Upstream version: ${RAW_UPSTREAM_TAG} | Source: (${SOURCE_FILE_INFO})"
    read -r -p "Update images.yaml for '${KEY}' to upstream tag '${RAW_UPSTREAM_TAG}'? [y/N]: " answer
    case "${answer}" in
    [yY] | [yY][eE][sS])
      update_images_yaml_tag "${KEY}" "${LOCAL_FULL_IMAGE}" "${RAW_UPSTREAM_TAG}"
      ;;
    *)
      echo "Skipped updating '${KEY}'."
      ;;
    esac
  else
    echo "OK: ${KEY} is current (Version: ${LOCAL_TAG_RAW})"
  fi
done
