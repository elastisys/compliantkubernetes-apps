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

# Days to compact
: "${COMPACT_DAYS:?Missing COMPACT_DAYS}"

LIMIT="$(date --utc --date="$COMPACT_DAYS days ago" '+%Y%m%d')"
NOW="$(date --utc '+%Y%m%d%H%M%S')"

SEQ=0

TMP_DIR="${TMP_DIR:-"/tmp"}"
LM_TMP="${TMP_DIR}/lm"
SORT_TMP="${TMP_DIR}/sort"

mkdir -p "$LM_TMP"
mkdir -p "$SORT_TMP"

# Define functions for the S3 operations
s3_list_days() {
  s3cmd --config "$S3_CONFIG" ls "s3://$S3_BUCKET/$S3_PREFIX/" | grep 'DIR' | awk '{print $2}' | sed "s#s3://$S3_BUCKET/$S3_PREFIX/##" | sed 's#/$##'
}

s3_list_indices() {
  S3_PATH="$1"

  s3cmd --config "$S3_CONFIG" ls "s3://$S3_BUCKET/$S3_PREFIX/$S3_PATH/" | grep 'DIR' | awk '{print $2}' | sed "s#s3://$S3_BUCKET/$S3_PREFIX/$S3_PATH/##" | sed 's#/$##'
}

s3_list_chunks() {
  S3_PATH="$1"

  s3cmd --config "$S3_CONFIG" ls -r "s3://$S3_BUCKET/$S3_PREFIX/$S3_PATH/" | grep '\.gz\|\.zst' | awk '{print $4}' | sed "s#s3://$S3_BUCKET/$S3_PREFIX/$S3_PATH/##"
}

s3_get_chunks() {
  S3_PATH="$1"
  CHUNK_DIR="$2"

  s3cmd --config "$S3_CONFIG" get -r "s3://$S3_BUCKET/$S3_PREFIX/$S3_PATH" "$CHUNK_DIR" > /dev/null
}

s3_put_chunk() {
  S3_PATH="$1"
  CHUNK_FILE="$2"

  s3cmd --config "$S3_CONFIG" put --no-preserve "$CHUNK_FILE" "s3://$S3_BUCKET/$S3_PREFIX/$S3_PATH/" > /dev/null
}

s3_rm_chunks() {
  CHUNK_LIST="$1"

  xargs -n1000 s3cmd --config "$S3_CONFIG" rm < "$CHUNK_LIST" > /dev/null
}

# Define functions for Azure operations
azure_list_days() {
    az storage blob directory list --container-name "$AZURE_CONTAINER_NAME" --directory-path "$AZURE_PREFIX" --prefix "$AZURE_PREFIX/" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" --output tsv | awk '{print $1}'
}

azure_list_indices() {
    AZURE_PATH="$1"
    az storage blob directory list --container-name "$AZURE_CONTAINER_NAME"  --directory-path "$AZURE_PREFIX" --prefix "${AZURE_PREFIX}/${AZURE_PATH}/" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" --output tsv | awk '{print $1}'
}

azure_list_chunks() {
    AZURE_PATH="$1"
    az storage blob list --container-name "$AZURE_CONTAINER_NAME" --prefix "${AZURE_PREFIX}/${AZURE_PATH}/" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" --output tsv | grep '\.gz\|\.zst' | awk '{print $1}'
}

azure_get_chunks() {
    AZURE_PATH="$1"
    CHUNK_DIR="$2"
    az storage blob download-batch -d "$CHUNK_DIR" --pattern '*.gz' --pattern '*.zst' --source "${AZURE_CONTAINER_NAME}/${AZURE_PREFIX}/${AZURE_PATH}" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" > /dev/null
}

azure_put_chunk() {
    AZURE_PATH="$1"
    CHUNK_FILE="$2"
    az storage blob upload --file "$CHUNK_FILE" --container-name "$AZURE_CONTAINER_NAME" --name "${AZURE_PREFIX}/${AZURE_PATH}/$(basename "$CHUNK_FILE")" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" > /dev/null
}

azure_rm_chunks() {
    CHUNK_LIST="$1"
    while IFS= read -r line; do
        az storage blob delete --container-name "$AZURE_CONTAINER_NAME" --name "${AZURE_PREFIX}/${line}" --connection-string "$AZURE_STORAGE_CONNECTION_STRING" > /dev/null
    done < "$CHUNK_LIST"
}

# Update merge_chunks function to support Azure Blob
merge_chunks() {
  DAY="$1"

  if [ "$STORAGE_SERVICE" = "azure" ]; then
    INDICES="$(azure_list_indices "$DAY")"
    CHUNKS="$(azure_list_chunks "$DAY")"
  else
    INDICES="$(s3_list_indices "$DAY")"
    CHUNKS="$(s3_list_chunks "$DAY")"
  fi

  for INDEX in $INDICES; do
    if [ "$(echo "$CHUNKS" | grep -c "$INDEX")" -lt 2 ]; then
      continue
    fi

    echo "--- merging chunks in $DAY/$INDEX"

    echo "----- fetching chunks"
    if [ "$STORAGE_SERVICE" = "azure" ]; then
      azure_get_chunks "$DAY/$INDEX" "$LM_TMP"
    else
      s3_get_chunks "$DAY/$INDEX" "$LM_TMP"
    fi

    TMPFILE="$(printf "%s/%s/%s-%05d" "$LM_TMP" "$INDEX" "$NOW" "$SEQ")"
    touch "$TMPFILE.idx"
    touch "$TMPFILE.log"

    echo "----- expanding chunks"
    for FILE in "$LM_TMP/$INDEX"/*; do
      if [[ "$FILE" =~ "$TMPFILE"* ]]; then
        continue
      fi

      if [ "$STORAGE_SERVICE" = "azure" ]; then
        echo "azure://${AZURE_CONTAINER_NAME}/${AZURE_PREFIX}/${DAY}/${FILE/$LM_TMP\//}" >> "$TMPFILE.idx"
      else
        echo "s3://$S3_BUCKET/$S3_PREFIX/$DAY/${FILE/$LM_TMP\//}" >> "$TMPFILE.idx"
      fi

      zstd --rm -c -d "$FILE"
    done | sort --compress-program=zstd --temporary-directory="$SORT_TMP" -u -S 100M | zstd -o "$TMPFILE.zst"

    echo "----- uploading chunk"
    if [ "$STORAGE_SERVICE" = "azure" ]; then
      azure_put_chunk "$DAY/$INDEX" "$TMPFILE.zst"
    else
      s3_put_chunk "$DAY/$INDEX" "$TMPFILE.zst"
    fi

    rm "$TMPFILE.zst"

    echo "----- clearing chunks"
    if [ "$STORAGE_SERVICE" = "azure" ]; then
      azure_rm_chunks "$TMPFILE.idx"
    else
      s3_rm_chunks "$TMPFILE.idx"
    fi

    rm "$TMPFILE.idx"

    echo "----- clearing temporary files"
    rm -r "${LM_TMP:?}/$INDEX"

    SEQ=$((SEQ + 1))
  done
}


if [[ "$STORAGE_SERVICE" == "azure" ]]; then
  days=$(azure_list_days)
else
  days=$(s3_list_days)
fi
for DAY in ${days}; do
  if [[ "$DAY" > "$LIMIT" ]]; then
    echo "- day: $DAY -----"
    merge_chunks "$DAY"
  fi
done

echo "---"
echo "end"
