#!/usr/bin/env bash

set -euo pipefail

: "${SCHEDULE_DAYS:?"Missing SCHEDULE_DAYS"}"
: "${SCHEDULE_START:?"Missing SCHEDULE_START"}"

here="$(dirname "$(readlink -f "${0}")")"

current="$(date --utc  +%y%m%d)"
current_timestamp="$(date --utc +%s --date "${current}")"
schedule_start_timestamp="$(date --utc +%s --date "${SCHEDULE_START}")"
days_since_schedule_start="$(( (current_timestamp - schedule_start_timestamp) / (3600 * 24) ))"

if [[ "${days_since_schedule_start}" -lt 0 ]]; then
  echo "skipping: $(( -1 * days_since_schedule_start )) days left before schedule starts"
  exit

elif (( days_since_schedule_start % SCHEDULE_DAYS )); then
  echo "skipping: $(( days_since_schedule_start % SCHEDULE_DAYS )) days left according to schedule"
  exit
fi

echo "triggering Tekton pipeline"

timestamp="$(date --utc +%y%m%d%H%M%S)" envsubst < "${here}/pipelinerun.yaml" | kubectl apply -f -
