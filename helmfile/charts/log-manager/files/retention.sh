#!/usr/bin/env bash

set -euo pipefail

: "${S3_CONFIG:?Missing S3_CONFIG}"
: "${S3_BUCKET:?Missing S3_BUCKET}"
: "${S3_PREFIX:?Missing S3_PREFIX}"

# Days to retain
: "${RETAIN_DAYS:?Missing RETAIN_DAYS}"

LIMIT="$(date --utc --date="$RETAIN_DAYS days ago" '+%Y%m%d')"

TMPFILE="/tmp/lm.idx"

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

for DAY in $(s3_list_days); do
  if [[ "$DAY" < "$LIMIT" ]]; then
    echo "- day: $DAY -----"

    echo "----- listing chunks"
    s3_list_chunks "$DAY" > "$TMPFILE"

    echo "----- clearing chunks"
    s3_rm_chunks "$TMPFILE"
  fi
done

echo "---"
echo "end"
