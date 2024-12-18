#!/usr/bin/env bash

# Script that test if prometheus targets exist and are healthy

# Fetch the data set
function getData() {
  jsonData=$(curl --silent 'http://localhost:9090/api/v1/targets')
  # Simplify the data by filtering out parts we do not need
  echo "${jsonData}" |
    jq '.data.activeTargets[] |
            {job: .scrapePool , health: .health, instance: .labels.instance}'
}

# Get the current count of healthy instances.
# Exit code 1 if the current count does not match the desired.
#Args:
#   1. data from prometheus
#   2. target name
#   2. expected target instances
function check_target() {
  data="${1}"
  targetName="${2}"
  desiredInstanceAmount="${3}"

  # Stores the value value of the "instance" key where the
  # "job" key matches the value of the current target being tested
  # The number of healthy instances
  currentInstanceAmount=$(echo "${data}" |
    jq -r --arg target "${targetName}" '. |
            select(.job==$target and .health=="up") |
            .instance' | wc -w)

  echo "${currentInstanceAmount}"
  if [[ ${currentInstanceAmount} == "${desiredInstanceAmount}" ]]; then
    return 0
  else
    return 1
  fi
}

# Check if the target is healthy and increment SUCCESSES or FAILURES accordingly
#Args:
#   1. data from prometheus
#   2. target name
#   2. expected target instances
function test_target() {
  data="${1}"
  targetName="${2}"
  desiredHealthy="${3}"

  if check_target "${data}" "${targetName}" "${desiredHealthy}" &>/dev/null; then
    echo -e "${targetName}\t✔"
    SUCCESSES=$((SUCCESSES + 1))
  else
    echo -e "${targetName}\t❌"
    FAILURES=$((FAILURES + 1))
    DEBUG_PROMETHEUS_TARGETS+=("${targetName}")
  fi
}

function test_targets_retry() {
  prometheusEndpoint="${1}"
  shift
  targets=("${@}")

  {
    # Run port-forward instance as a background process
    kubectl port-forward -n monitoring "${prometheusEndpoint}" 9090 &
    PF_PID=$!
    sleep 3
  } &>/dev/null

  # TODO: Why is this not working?
  # trap 'kill "${PF_PID}"; wait "${PF_PID}" 2>/dev/null' RETURN

  echo -n "Checking targets up to 5 times to avoid flakes..."
  for i in {1..5}; do
    # Get data from prometheus
    jsonData=$(getData)

    # Print progress
    echo -n " ${i}"

    # Check all targets
    # If there are failures we need to retry
    failure=0
    for target in "${targets[@]}"; do
      read -r -a arr <<<"${target}"
      name="${arr[0]}"
      instances="${arr[1]}"
      if ! check_target "${jsonData}" "${name}" "${instances}" &>/dev/null; then
        failure=1
        break
      fi
    done

    # If no failures, we are ready to move on
    if [ ${failure} -eq 0 ]; then
      break
    fi
    sleep 10
  done

  kill "${PF_PID}"
  wait "${PF_PID}" 2>/dev/null

  echo -e "\nRunning tests..."
  # Test all targets
  for target in "${targets[@]}"; do
    read -r -a arr <<<"${target}"
    name="${arr[0]}"
    instances="${arr[1]}"
    test_target "${jsonData}" "${name}" "${instances}"
  done
}
