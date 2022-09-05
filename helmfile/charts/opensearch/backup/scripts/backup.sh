#!/usr/bin/env bash

set -euo pipefail

: "${OPENSEARCH_ENDPOINT:?Missing OPENSEARCH_ENDPOINT}"
: "${OPENSEARCH_USERNAME:?Missing OPENSEARCH_USERNAME}"
: "${OPENSEARCH_PASSWORD:?Missing OPENSEARCH_PASSWORD}"
: "${SNAPSHOT_REPOSITORY:?Missing SNAPSHOT_REPOSITORY}"
: "${INDICES:?Missing INDICES}"

curl --insecure -s -i -u "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" \
    -XPUT "https://${OPENSEARCH_ENDPOINT}/_snapshot/${SNAPSHOT_REPOSITORY}/snapshot-$(date --utc +%Y%m%d_%H%M%Sz)" \
    -H "Content-Type: application/json" -d'
    {
        "indices": "'"${INDICES}"'",
        "include_global_state": false
    }' \
    | tee /dev/stderr | grep "200 OK"
