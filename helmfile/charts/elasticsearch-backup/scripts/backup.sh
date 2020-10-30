#!/usr/bin/env bash

set -euo pipefail

: "${ELASTICSEARCH_API_USER:?Missing ELASTICSEARCH_API_USER}"
: "${ELASTICSEARCH_API_PASSWORD:?Missing ELASTICSEARCH_API_PASSWORD}"
: "${ELASTICSEARCH_ENDPOINT:?Missing ELASTICSEARCH_ENDPOINT}"
: "${SNAPSHOT_REPOSITORY:?Missing SNAPSHOT_REPOSITORY}"
: "${INDICES:?Missing INDICES}"

curl -s -i -u "${ELASTICSEARCH_API_USER}:${ELASTICSEARCH_API_PASSWORD}" \
    -XPUT "http://${ELASTICSEARCH_ENDPOINT}/_snapshot/${SNAPSHOT_REPOSITORY}/snapshot-$(date --utc +%Y%m%d_%H%M%Sz)" \
    -H "Content-Type: application/json" -d'
    {
        "indices": "'"${INDICES}"'",
        "include_global_state": false
    }' \
    | tee /dev/stderr | grep "200 OK"
