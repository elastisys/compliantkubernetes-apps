#!/bin/bash
set -euo pipefail

# --- Input Validation and Configuration ---
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <UPSTREAM_CHART_PATH>"
  echo "Example (All Charts): $0 ./helmfile.d/upstream"
  echo "Example (Single Umbrella Chart): $0 ./helmfile.d/upstream/prometheus-community/kube-prometheus-stack"
  exit 1
fi

INPUT_PATH="$1"
IMAGES_YAML_PATH="./helmfile.d/lists/images.yaml"

if [ ! -f "./scripts/image_mapping.sh" ]; then
  echo "ERROR: Mapping file 'image_mapping.sh' not found. Please ensure it is in the same directory."
  exit 1
fi
source ./scripts/image_mapping.sh

# --- Determine Scope (Single Chart or All Charts) ---
LAST_PATH_COMPONENT=$(basename "$INPUT_PATH")
CHART_FILTER=""
UPSTREAM_BASE_DIR=""

if [ -f "$INPUT_PATH/values.yaml" ]; then
  # Single Chart Mode: Input path is the chart directory.
  CHECK_SCOPE="Single Chart: $LAST_PATH_COMPONENT"
  CHART_FILTER="$LAST_PATH_COMPONENT"

  for KEY in "${!IMAGE_MAPPING[@]}"; do
    MAP_VALUE="${IMAGE_MAPPING[$KEY]}"
    CHART_PATH=$(echo "$MAP_VALUE" | cut -d';' -f1)
    CHART_NAME=$(basename "$CHART_PATH")

    if [ "$CHART_NAME" = "$CHART_FILTER" ] && [[ "$INPUT_PATH" =~ /$CHART_PATH$ ]]; then
      UPSTREAM_BASE_DIR="${INPUT_PATH/%$CHART_PATH/}"
      break
    fi
  done

  if [ -z "$UPSTREAM_BASE_DIR" ]; then
    echo "ERROR: Could not find a matching top-level chart entry in mapping.sh for input path '$INPUT_PATH'."
    echo "Please ensure the entry for '$CHART_FILTER' exactly matches the end of your input path."
    exit 1
  fi
else
  # All Charts Mode: Input path is the base directory.
  CHECK_SCOPE="All Charts in Base Dir"
  UPSTREAM_BASE_DIR="$INPUT_PATH"
fi

echo "--- Starting Image Drift Check ---"
echo "Scope: $CHECK_SCOPE"

# Loop through all mappings
for KEY in "${!IMAGE_MAPPING[@]}"; do
  # Extract map values
  MAP_VALUE="${IMAGE_MAPPING[$KEY]}"
  CHART_PATH=$(echo "$MAP_VALUE" | cut -d';' -f1)
  UPSTREAM_PATH=$(echo "$MAP_VALUE" | cut -d';' -f2)
  FLAG=$(echo "$MAP_VALUE" | cut -d';' -f3)

  CHART_NAME=$(basename "$CHART_PATH")

  if [ -n "$CHART_FILTER" ]; then
    if [ "$CHART_NAME" != "$CHART_FILTER" ] && [[ "$CHART_PATH" != *"$CHART_FILTER"* ]]; then
      continue
    fi
  fi

  # --- File Path Assembly ---
  UPSTREAM_VALUES_FILE=$(echo "${UPSTREAM_BASE_DIR}${CHART_PATH}/values.yaml" | sed 's/\/\//\//g')
  UPSTREAM_CHART_FILE=$(echo "${UPSTREAM_BASE_DIR}${CHART_PATH}/Chart.yaml" | sed 's/\/\//\//g')

  # --- Fetch Local Image Details ---
  LOCAL_FULL_IMAGE=$(yq ".images.$KEY" "$IMAGES_YAML_PATH" 2>/dev/null)

  if [ "$LOCAL_FULL_IMAGE" = "null" ]; then
    echo "WARN: Local image key '$KEY' not found in $IMAGES_YAML_PATH. Skipping."
    continue
  fi

  LOCAL_TAG=$(echo "$LOCAL_FULL_IMAGE" | awk -F '[:@]' '{print $NF}')

  LOCAL_TAG_NORMALIZED=$(echo "$LOCAL_TAG" | sed 's/^[vV]//')

  # --- Fetch Upstream Tag (Logic depends on the flag) ---
  UPSTREAM_TAG=""
  SOURCE_FILE_INFO=""

  if [ "$FLAG" -eq 2 ] || [ "$FLAG" -eq 3 ]; then
    # Use AppVersion from Chart.yaml
    if [ ! -f "$UPSTREAM_CHART_FILE" ]; then
      echo "ERROR: Upstream Chart.yaml file not found: '$UPSTREAM_CHART_FILE' for chart '$CHART_PATH'. Skipping check for '$KEY'."
      continue
    fi

    # Pull the AppVersion
    RAW_UPSTREAM_TAG=$(yq ".appVersion" "$UPSTREAM_CHART_FILE" 2>/dev/null | tr -d '"')

    UPSTREAM_TAG=$(echo "$RAW_UPSTREAM_TAG" | sed 's/^[vV]//')

    SOURCE_FILE_INFO="Chart.yaml (AppVersion)"

  elif [ ! -f "$UPSTREAM_VALUES_FILE" ]; then
    echo "ERROR: Upstream values file not found: '$UPSTREAM_VALUES_FILE' for chart '$CHART_PATH'. Skipping check for '$KEY'."
    continue
  else
    # Use Tag from values.yaml
    RAW_UPSTREAM_TAG=$(yq "$UPSTREAM_PATH" "$UPSTREAM_VALUES_FILE" 2>/dev/null | tr -d '"')

    if [ -z "$RAW_UPSTREAM_TAG" ] || [ "$RAW_UPSTREAM_TAG" = "null" ]; then
      echo "WARN: Chart '$CHART_PATH' - Path '$UPSTREAM_PATH' in values.yaml returned empty/null tag. Skipping check for '$KEY'."
      continue
    fi

    UPSTREAM_TAG=$(echo "$RAW_UPSTREAM_TAG" | sed 's/^[vV]//')

    SOURCE_FILE_INFO="values.yaml ($UPSTREAM_PATH)"
  fi

  if [ "$LOCAL_TAG_NORMALIZED" != "$UPSTREAM_TAG" ]; then
    echo "DRIFT DETECTED for $KEY (Chart Path: $CHART_PATH)"
    # Display the original tags for context
    echo "  Local version:    $LOCAL_TAG ($LOCAL_TAG_NORMALIZED)"
    echo "  Upstream version: $UPSTREAM_TAG ($SOURCE_FILE_INFO)"
  else
    echo "OK: $KEY is current (Version: $LOCAL_TAG)"
  fi
done
