#!/usr/bin/env bash

# This script manages snapshot lifecycle management in an opendistro
# elasticsearch cluster.
#
# The overall flow of this script is as following:
# - if there are old snapshots:
#   - remove them until there are no snapshots older than MAX_AGE_SECONDS or MIN_SNAPSHOTS snapshots left
# - if there are an excess amount of snapshots:
#   - remove them until there are MAX_SNAPSHOTS snapshots left
#

set -euo pipefail

: "${MIN_SNAPSHOTS:?Missing MIN_SNAPSHOTS}"
: "${MAX_SNAPSHOTS:?Missing MAX_SNAPSHOTS}"
: "${MAX_AGE_SECONDS:?Missing MAX_AGE_SECONDS}"
: "${ELASTICSEARCH_API_USER:?Missing ELASTICSEARCH_API_USER}"
: "${ELASTICSEARCH_API_PASSWORD:?Missing ELASTICSEARCH_API_PASSWORD}"
: "${ELASTICSEARCH_ENDPOINT:?Missing ELASTICSEARCH_ENDPOINT}"
: "${SNAPSHOT_REPOSITORY:?Missing SNAPSHOT_REPOSITORY}"

ELASTICSEARCH_URL="http://${ELASTICSEARCH_ENDPOINT}"
REQUEST_TIMEOUT_SECONDS=600

# Snapshots returned from this function should be succeeded, or depending on
# how it was created, partial.
# https://opendistro.github.io/for-elasticsearch-docs/docs/elasticsearch/snapshot-restore/#take-snapshots
function get_snapshots {
    local url="${ELASTICSEARCH_URL}/_snapshot/${SNAPSHOT_REPOSITORY}/_all"
    curl "${url}" -f -X GET --max-time "${REQUEST_TIMEOUT_SECONDS}" --silent \
        --basic --user "${ELASTICSEARCH_API_USER}:${ELASTICSEARCH_API_PASSWORD}" \
        | jq '.snapshots | sort_by(.start_time_in_millis)'
}

function get_snapshot_age {
    local snapshots=$1
    local idx=$2
    local snapshot_start_date
    local snapshot_start_date_seconds
    local now_seconds
    local age_seconds

    snapshot_start_date=$(echo "${snapshots}" | jq -r ".[${idx}].start_time")
    snapshot_start_date_seconds=$(date --date="${snapshot_start_date}" +%s)
    now_seconds=$(date +%s)
    age_seconds=$((now_seconds - snapshot_start_date_seconds))
    echo "${age_seconds}"
}

function remove_snapshot {
    local snapshot_name=$1
    local url="${ELASTICSEARCH_URL}/_snapshot/${SNAPSHOT_REPOSITORY}/${snapshot_name}"
    curl "${url}" -f -X DELETE --max-time "${REQUEST_TIMEOUT_SECONDS}" --silent \
        --basic --user "${ELASTICSEARCH_API_USER}:${ELASTICSEARCH_API_PASSWORD}"
}

function check_snapshot_count {
    local snapshot_count=$1
    if [ "${snapshot_count}" -le "${MIN_SNAPSHOTS}" ]; then
        echo "snapshot count: ${snapshot_count} fewer than minimum: ${MIN_SNAPSHOTS}, do nothing"
        return 1
    fi
}

function check_old_snapshots {
    local snapshots=$1
    if [ "$(get_snapshot_age "${snapshots}" 0)" -le "${MAX_AGE_SECONDS}" ]; then
        echo "no old snapshots"
        return 1
    fi
}

function remove_old_snapshots {
    local idx=0
    local snapshots
    local snapshot_count

    snapshots=$(get_snapshots)
    snapshot_count=$(echo "${snapshots}" | jq length)

    check_snapshot_count "${snapshot_count}" || exit 0
    check_old_snapshots  "${snapshots}"      || exit 0

    while [ $((snapshot_count - idx )) -gt "${MIN_SNAPSHOTS}" ]; do
        local age_seconds
        age_seconds=$(get_snapshot_age "${snapshots}" "${idx}")
        if [ "${age_seconds}" -gt "${MAX_AGE_SECONDS}" ]; then
            local snapshot_name
            snapshot_name=$(echo "${snapshots}" | jq -r ".[${idx}].snapshot")
            echo "snapshot ${snapshot_name} is ${age_seconds} s old, max ${MAX_AGE_SECONDS} s"
            remove_snapshot "${snapshot_name}"
        fi
        idx=$((idx + 1))
    done
}

function remove_excess_snapshots {
    local idx=0
    local snapshots
    local snapshot_count

    snapshots=$(get_snapshots)
    snapshot_count=$(echo "${snapshots}" | jq length)

    check_snapshot_count "${snapshot_count}" || exit 0

    while [ $((snapshot_count - idx )) -gt "${MAX_SNAPSHOTS}" ]; do
        local snapshot_name
        snapshot_name=$(echo "${snapshots}" | jq -r ".[${idx}].snapshot")
        echo "too many snapshots: $((snapshot_count - idx )), max ${MAX_SNAPSHOTS}"
        remove_snapshot "${snapshot_name}"
        idx=$((idx + 1))
    done
}

remove_old_snapshots
remove_excess_snapshots
