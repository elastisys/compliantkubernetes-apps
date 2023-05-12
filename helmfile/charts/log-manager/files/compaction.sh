#!/usr/bin/env bash

set -euo pipefail

: "${S3_CONFIG:?Missing S3_CONFIG}"
: "${S3_BUCKET:?Missing S3_BUCKET}"
: "${S3_PREFIX:?Missing S3_PREFIX}"

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

merge_chunks() {
  DAY="$1"

  INDICES="$(s3_list_indices "$DAY")"
  CHUNKS="$(s3_list_chunks "$DAY")"

  for INDEX in $INDICES; do
    if [ "$(echo "$CHUNKS" | grep -c "$INDEX")" -lt 2 ]; then
      continue
    fi

    echo "--- merging chunks in $DAY/$INDEX"

    echo "----- fetching chunks"
    s3_get_chunks "$DAY/$INDEX" "$LM_TMP"

    TMPFILE="$(printf "%s/%s/%s-%05d" "$LM_TMP" "$INDEX" "$NOW" "$SEQ")"
    touch "$TMPFILE.idx"
    touch "$TMPFILE.log"

    echo "----- expanding chunks"
    for FILE in "$LM_TMP/$INDEX"/*; do
      if [[ "$FILE" =~ "$TMPFILE"* ]]; then
        continue
      fi

      echo "s3://$S3_BUCKET/$S3_PREFIX/$DAY/${FILE/$LM_TMP\//}" >> "$TMPFILE.idx"

      zstd -c -d --rm "$FILE" >> "$TMPFILE.log"
    done

    echo "----- sorting chunk"
    sort --temporary-directory="$SORT_TMP" -u -S 100M -o "$TMPFILE.log" "$TMPFILE.log"

    echo "----- compressing chunk"
    zstd --rm -o "$TMPFILE.zst" "$TMPFILE.log"

    echo "----- uploading chunk"
    s3_put_chunk "$DAY/$INDEX" "$TMPFILE.zst"

    rm "$TMPFILE.zst"

    echo "----- clearing chunks"
    s3_rm_chunks "$TMPFILE.idx"

    rm "$TMPFILE.idx"

    SEQ=$((SEQ + 1))
  done
}

for DAY in $(s3_list_days); do
  if [[ "$DAY" > "$LIMIT" ]]; then
    echo "- day: $DAY -----"
    merge_chunks "$DAY"
  fi
done

echo "---"
echo "end"
