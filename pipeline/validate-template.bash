#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "${0}")")"

validate() {
  echo "--- ${1} cluster ---"

  helmfile -e "${1}_cluster" -f "${here}/../helmfile/" -q template | kubeconform --ignore-missing-schemas -schema-location default -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' --strict --summary -
}

ret=0

if ! validate service; then
  ret=1
fi

if ! validate workload; then
  ret=1
fi

echo "---"

if [[ "${ret}" -eq 0 ]]; then
  echo "template validation success"
else
  echo "template validation failure"
  exit 1
fi
