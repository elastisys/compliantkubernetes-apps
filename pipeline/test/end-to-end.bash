#!/usr/bin/env bash

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

set -u -o pipefail

root=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
log_dir=${root}/logs

if [ ! -d "${log_dir}" ]; then
  mkdir -p "${log_dir}"
fi

test_dir="${root}/tests"

mapfile -t dirs < <(find end-to-end -mindepth 1 -maxdepth 1 -type d ! -name '.*' -printf '%f\n')

for dir in "${dirs[@]}"; do
  log_file="${log_dir}/end-to-end-${dir}.log"
  if ! bats -r "${test_dir}/end-to-end/${dir}" 2>&1 | tee "${log_file}"; then
    echo "Test for ${dir} failed. See ${log_file} for details."
  else
    rm "${log_file}"
  fi
done
