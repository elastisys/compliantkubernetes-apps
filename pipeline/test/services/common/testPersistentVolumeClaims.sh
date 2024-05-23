#!/usr/bin/env bash

testPersistentVolumeClaims() {
  local pvcs name namespace phase output

  echo
  echo
  echo "Testing Persistent Volume Claims"
  echo "================================"

  pvcs=$(kubectl get pvc --all-namespaces -o json)

  while read -r pvc; do
    name=$(echo "$pvc" | jq -r '.metadata.name')
    namespace=$(echo "$pvc" | jq -r '.metadata.namespace')
    phase=$(echo "$pvc" | jq -r '.status.phase')
    output="$namespace/$name: $phase"
    if [ "$phase" = Bound ]; then
      echo "$output ✔"
      SUCCESSES=$((SUCCESSES+1))
    else
      echo "$output ❌"
      FAILURES=$((FAILURES+1))
      DEBUG_OUTPUT+=$pvc
    fi
  done < <(echo "$pvcs" | jq -c '.items[]')
}

testPersistentVolumeClaims
