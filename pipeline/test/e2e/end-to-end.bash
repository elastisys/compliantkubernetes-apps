#!/usr/bin/env bash

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

set -u -o pipefail

here="$(dirname "$(readlink -f "$0")")"
root="${here}/../../.."
LOGSFOLDER="${root}/logs"

cd "${root}/tests" || exit
mapfile -t dirs < <(find end-to-end -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n')

if [ ! -d "${LOGSFOLDER}" ]; then
  mkdir -p "${LOGSFOLDER}"
fi

for dir in "${dirs[@]}"; do
  log_file="${LOGSFOLDER}/end-to-end-${dir}.log"
  if ! make run-end-to-end/"${dir}" >"${log_file}" 2>&1; then
    echo "E2E test for ${dir} failed. See ${log_file} for details."
  else
    rm "${log_file}"
  fi
done
