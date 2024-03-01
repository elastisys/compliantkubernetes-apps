#!/usr/bin/env bash

set -euo pipefail

if [ "$STORAGE_SERVICE" = "azure" ]; then
# Azure Blob configuration
  : "${AZURE_STORAGE_CONNECTION_STRING:?Missing AZURE_STORAGE_CONNECTION_STRING}"
  : "${AZURE_CONTAINER_NAME:?Missing AZURE_CONTAINER_NAME}"
  : "${AZURE_PREFIX:?Missing AZURE_PREFIX}"
else
# S3 configuration
  : "${S3_CONFIG:?Missing S3_CONFIG}"
  : "${S3_BUCKET:?Missing S3_BUCKET}"
  : "${S3_PREFIX:?Missing S3_PREFIX}"
fi

# Days to retain
: "${RETAIN_DAYS:?Missing RETAIN_DAYS}"

LIMIT="$(date --utc --date="$RETAIN_DAYS days ago" '+%Y%m%d')"

TMPFILE="/tmp/lm.idx"

# Define S3 functions
s3_list_days() {
  s3cmd --config "$S3_CONFIG" ls "s3://$S3_BUCKET/$S3_PREFIX/" | grep 'DIR' | awk '{print $2}' | sed "s#s3://$S3_BUCKET/$S3_PREFIX/##" | sed 's#/$##'
}

s3_list_chunks() {
  S3_PATH="$1"

  s3cmd --config "$S3_CONFIG" ls -r "s3://$S3_BUCKET/$S3_PREFIX/$S3_PATH/" | grep '\.gz\|\.zst' | awk '{print $4}'
}

s3_rm_chunks() {
  CHUNK_LIST="$1"

  xargs -n1000 s3cmd --config "$S3_CONFIG" rm < "$CHUNK_LIST" > /dev/null
}

# Define Azure Blob functions
azure_list_days() {
    az storage blob directory list --container-name "$AZURE_CONTAINER_NAME" --directory-path "$AZURE_PREFIX" --prefix "$AZURE_PREFIX/" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" --output tsv | awk '{print $1}'
}

azure_list_chunks() {
    AZURE_PATH="$1"
    az storage blob list --container-name "$AZURE_CONTAINER_NAME" --prefix "${AZURE_PREFIX}/${AZURE_PATH}/" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" --output tsv | grep '\.gz\|\.zst' | awk '{print $1}'
}

azure_rm_chunks() {
    CHUNK_LIST="$1"
    while IFS= read -r line; do
        az storage blob delete --container-name "$AZURE_CONTAINER_NAME" --name "${AZURE_PREFIX}/${line}" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" > /dev/null
    done < "$CHUNK_LIST"
}

# Main loop
if [[ "$STORAGE_SERVICE" == "azure" ]]; then
  for DAY in $(azure_list_days); do
    if [[ "$DAY" < "$LIMIT" ]]; then
      echo "- day: $DAY -----"
      echo "----- listing Azure chunks"
      azure_list_chunks "$DAY" > "$TMPFILE"
      echo "----- clearing Azure chunks"
      azure_rm_chunks "$TMPFILE"
    fi
  done
else
  for DAY in $(s3_list_days); do
    if [[ "$DAY" < "$LIMIT" ]]; then
      echo "- day: $DAY -----"
      echo "----- listing S3 chunks"
      s3_list_chunks "$DAY" > "$TMPFILE"
      echo "----- clearing S3 chunks"
      s3_rm_chunks "$TMPFILE"
    fi
  done
fi

echo "---"
echo "end"
