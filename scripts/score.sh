#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "${0}")")"

if ! command -v kube-score &> /dev/null; then
  echo "error: kube-score (https://github.com/zegl/kube-score) is required for running this script"
  exit 1
fi

score() {
  namespaces="$(helmfile -e "${1}_cluster" -f "${here}/../helmfile/" list -q --output json | yq4 '[.[].namespace] | sort | unique | .[]')"

  for namespace in ${namespaces}; do
    helmfile -e "${1}_cluster" -f "${here}/../helmfile/" template -q "-lnamespace=${namespace}" | yq4 "with(select(.metadata.namespace == null); .metadata.namespace = \"${namespace}\")"
    echo "---"
  done | kube-score score - --ignore-test container-image-pull-policy,container-ephemeral-storage-request-and-limit,container-security-context-readonlyrootfilesystem,container-security-context-user-group-id --kubernetes-version v1.24
}

ret=0

if ! score service; then
  ret=1
fi

if ! score workload; then
  ret=1
fi

echo "---"

if [[ "${ret}" -eq 0 ]]; then
  echo "score pass"
else
  echo "score fail"
  exit 1
fi
