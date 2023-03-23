#!/usr/bin/env bash

for template in "${@}"; do
  echo "waiting - ${template}"
  attempts=30
  while [[ "$((attempts--))" -gt 0 ]]; do
    if [[ "$(kubectl get crd "${template}" -o 'jsonpath={.status.conditions[?(@.type=="Established")].status}')" == "True" ]]; then
      echo "established - ${template}"
      continue 2
    fi
    sleep 5
  done

  echo "time out - ${template}"
  exit 1
done
