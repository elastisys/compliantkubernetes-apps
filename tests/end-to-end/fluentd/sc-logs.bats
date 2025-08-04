#!/usr/bin/env bats

# bats file_tags=fluentd

set -o pipefail

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true

  load "../../bats.lib.bash"

  load_common "object-storage.bash"
  load_common "yq.bash"

  object_storage.load_env

  with_kubeconfig sc
  with_namespace "$(uuid)"

  create_namespace
}

teardown_file() {
  delete_namespace
}

setup() {
  load "../../bats.lib.bash"
  load_assert

  load_common "object-storage.bash"
  load_common "yq.bash"
}

@test "fluentd forwards SC logs to object storage" {
  local bucket
  bucket="$(yq.get sc '.objectStorage.buckets.scFluentd')"
  local prefix
  prefix="logs/$(date +"%Y%m%d")/kubernetes.var.log.containers"

  local destination="${BATS_TEST_TMPDIR}/audit-logs"
  mkdir "${destination}"

  object_storage.download_one "${bucket}" "${prefix}" "${destination}"

  run _get_log_message "${destination}"
  assert_success
  [ "${output}" != "" ]
}

@test "fluentd forwards new SC logs to object storage" {
  local max_fluent_interval_seconds="100"

  local flush_interval
  flush_interval="$(yq.get sc '.fluentd.aggregator.buffer.flushInterval')"

  skip_time_gt "${flush_interval}" "${max_fluent_interval_seconds}s" "aggregator flush interval too long"

  local log_message="sc-log test"

  local job_name
  job_name="$(uuid)"

  local bucket
  bucket="$(yq.get sc '.objectStorage.buckets.scFluentd')"
  local prefix
  prefix="logs/$(date +"%Y%m%d")/kubernetes.var.log.containers.${job_name}-"

  local destination="${BATS_TEST_TMPDIR}/${job_name}"
  mkdir "${destination}"

  run kubectl -n "${NAMESPACE}" create job "${job_name}" --image=busybox:1.37.0 -- /bin/sh -c 'echo '"${log_message}"
  assert_success

  test_job_complete "${job_name}"

  test_logs_contains job "${job_name}" "${log_message}"

  object_storage.wait "${bucket}" "${prefix}" "$((max_fluent_interval_seconds + 120))"

  object_storage.download "${bucket}" "${prefix}" "${destination}"

  run _get_log_message "${destination}"
  assert_success
  assert_output "${log_message}"
}

_get_log_message() {
  {
    find "${1}" -type f \( -name "*.gz" -o -name "*.zst" \) -print0 | while IFS= read -r -d '' file; do
      case "${file}" in
      *.gz) zcat "${file}" ;;
      *.zst) unzstd --stdout "${file}" ;;
      esac
    done
  } | cut -d $'\t' -f 3 | jq -r '.message'
}
