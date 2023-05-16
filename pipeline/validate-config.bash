#!/usr/bin/env bash

set -euo pipefail

here="$(dirname "$(readlink -f "${0}")")"

ret=0

if [[ "${CI:-}" == "true" ]]; then
  git config --global --add safe.directory /github/workspace
fi

echo "--- service cluster ---"
if ! "${here}/../bin/ck8s" validate sc <<< $'y\n'; then
  ret=1
fi

echo -e "\n--- workload cluster ---"
if ! "${here}/../bin/ck8s" validate wc <<< $'y\n'; then
  ret=1
fi

echo -e "\n---"

if [[ "${ret}" -eq 0 ]]; then
  echo "config validation success"
else
  echo "config validation failure"
  exit 1
fi
