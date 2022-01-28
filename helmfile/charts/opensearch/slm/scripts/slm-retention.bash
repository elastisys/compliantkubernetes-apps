#!/usr/bin/env bash

# This script manages snapshot lifecycle management in an opensearch cluster.
#
# The overall flow of this script is as following:
# - if there are old snapshots:
#   - remove them until there are no snapshots older than MAX_AGE_SECONDS or MIN_SNAPSHOTS snapshots left
# - if there are an excess amount of snapshots:
#   - remove them until there are MAX_SNAPSHOTS snapshots left
#

set -euo pipefail

: "${OPENSEARCH_ENDPOINT:?Missing OPENSEARCH_ENDPOINT}"
: "${OPENSEARCH_USERNAME:?Missing OPENSEARCH_USERNAME}"
: "${OPENSEARCH_PASSWORD:?Missing OPENSEARCH_PASSWORD}"
: "${MIN_SNAPSHOTS:?Missing MIN_SNAPSHOTS}"
: "${MAX_SNAPSHOTS:?Missing MAX_SNAPSHOTS}"
: "${MAX_AGE_SECONDS:?Missing MAX_AGE_SECONDS}"
: "${SNAPSHOT_REPOSITORY:?Missing SNAPSHOT_REPOSITORY}"
: "${REQUEST_TIMEOUT_SECONDS:?Missing REQUEST_TIMEOUT_SECONDS}"

# Make sure variables are integers
MAX_AGE_SECONDS=$(LC_ALL=C printf '%.0f\n' "${MAX_AGE_SECONDS}")
MAX_SNAPSHOTS=$(LC_ALL=C printf '%.0f\n' "${MAX_SNAPSHOTS}")
MIN_SNAPSHOTS=$(LC_ALL=C printf '%.0f\n' "${MIN_SNAPSHOTS}")
REQUEST_TIMEOUT_SECONDS=$(LC_ALL=C printf '%.0f\n' "${REQUEST_TIMEOUT_SECONDS}")

OPENSEARCH_URL="http://${OPENSEARCH_ENDPOINT}"

# Snapshots returned from this function should be succeeded, or depending on how it was created, partial.
# https://opensearch.org/docs/latest/opensearch/snapshot-restore
function get_snapshots {
    local url="${OPENSEARCH_URL}/_snapshot/${SNAPSHOT_REPOSITORY}/_all"
    curl "${url}" -f -X GET --max-time "${REQUEST_TIMEOUT_SECONDS}" --no-progress-meter \
        --basic --user "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}" \
        | jq '.snapshots | sort_by(.start_time_in_millis)'
    echo ""
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

function remove_snapshots {
    local snapshots_to_delete=$1
    local url="${OPENSEARCH_URL}/_snapshot/${SNAPSHOT_REPOSITORY}/${snapshots_to_delete}"
    echo "Deleting snapshots: ${snapshots_to_delete}"
    curl "${url}" -f -X DELETE --max-time "${REQUEST_TIMEOUT_SECONDS}" --no-progress-meter \
        --basic --user "${OPENSEARCH_USERNAME}:${OPENSEARCH_PASSWORD}"
    echo ""
}

function check_snapshot_count {
    local snapshot_count=$1
    if [ "${snapshot_count}" -le "${MIN_SNAPSHOTS}" ]; then
        echo "Snapshot count: ${snapshot_count} fewer than minimum: ${MIN_SNAPSHOTS}, do nothing"
        return 1
    fi
}

function check_old_snapshots {
    local snapshots=$1
    if [ "$(get_snapshot_age "${snapshots}" 0)" -le "${MAX_AGE_SECONDS}" ]; then
        echo "No old snapshots"
        return 1
    fi
}

function remove_old_snapshots {
    local idx=0
    local snapshots
    local snapshot_count
    local snapshots_to_delete=""

    echo "Checking for old snapshots."

    snapshots=$(get_snapshots)
    snapshot_count=$(echo "${snapshots}" | jq length)

    check_snapshot_count "${snapshot_count}" || return 0
    check_old_snapshots  "${snapshots}"      || return 0

    while [ $((snapshot_count - idx )) -gt "${MIN_SNAPSHOTS}" ]; do
        local age_seconds
        age_seconds=$(get_snapshot_age "${snapshots}" "${idx}")
        if [ "${age_seconds}" -gt "${MAX_AGE_SECONDS}" ]; then
            local snapshot_name
            snapshot_name=$(echo "${snapshots}" | jq -r ".[${idx}].snapshot")
            echo "Snapshot ${snapshot_name} is ${age_seconds} s old, max ${MAX_AGE_SECONDS} s"
            snapshots_to_delete="${snapshots_to_delete}${snapshot_name},"
        fi
        idx=$((idx + 1))
    done
    if [ -n "${snapshots_to_delete}" ]; then
        remove_snapshots "${snapshots_to_delete}"
    fi
}

function remove_excess_snapshots {
    local idx=0
    local snapshots
    local snapshot_count
    local snapshots_to_delete=""

    echo "Checking number of snapshots."

    snapshots=$(get_snapshots)
    snapshot_count=$(echo "${snapshots}" | jq length)
    echo "Number of snapshots: $snapshot_count"

    check_snapshot_count "${snapshot_count}" || return 0

    while [ $((snapshot_count - idx )) -gt "${MAX_SNAPSHOTS}" ]; do
        local snapshot_name
        snapshot_name=$(echo "${snapshots}" | jq -r ".[${idx}].snapshot")
        echo "Too many snapshots: $((snapshot_count - idx )), max ${MAX_SNAPSHOTS}"
        snapshots_to_delete="${snapshots_to_delete}${snapshot_name},"
        idx=$((idx + 1))
    done
    if [ -n "${snapshots_to_delete}" ]; then
        remove_snapshots "${snapshots_to_delete}"
    else
        echo "Snapshot count: ${snapshot_count} is not more than maximum: ${MAX_SNAPSHOTS}, do nothing"
    fi
}

echo "SLM retention procedure started"
echo "Removing snapshots older than ${MAX_AGE_SECONDS} seconds but keeping at least ${MIN_SNAPSHOTS} snapshots and at most ${MAX_SNAPSHOTS} snapshots."
remove_old_snapshots
remove_excess_snapshots
echo "SLM retention procedure done."
