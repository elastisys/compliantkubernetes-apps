#!/usr/bin/env bats

# Generated from tests/end-to-end/log-manager/compaction.bats.gotmpl

# bats file_tags=log-manager,audit-wc

set -o pipefail

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true

  load "../../bats.lib.bash"
  load_assert

  load_common "object-storage.bash"
  load_common "yq.bash"

  object_storage.load_env

  with_kubeconfig sc
  with_namespace fluentd-system

  CRONJOB_NAME="audit-$(yq.get sc '.global.ck8sEnvironmentName')-wc-compaction"
  export CRONJOB_NAME

  kubectl -n "${NAMESPACE}" patch cronjob "${CRONJOB_NAME}" -p '{"spec" : {"suspend" : true}}'
  terminate_cronjob_jobs "${CRONJOB_NAME}" 300

  local cronjob_env_bucket
  local cronjob_env_prefix

  local object_storage_type
  object_storage_type="$(yq.get sc '.objectStorage.type')"
  case "${object_storage_type}" in
  "s3")
    cronjob_env_bucket="S3_BUCKET"
    cronjob_env_prefix="S3_PREFIX"
    ;;
  "azure")
    cronjob_env_bucket="AZURE_CONTAINER_NAME"
    cronjob_env_prefix="AZURE_PREFIX"
    ;;
  *)
    fail "Unsupported object storage type: ${object_storage_type}"
    ;;
  esac

  BUCKET="$(_get_cronjob_env "${cronjob_env_bucket}")"
  export BUCKET
  PREFIX="$(_get_cronjob_env "${cronjob_env_prefix}")"
  export PREFIX

  [ -n "${BUCKET}" ] || fail "Failed to get bucket name from cronjob"
  [ -n "${PREFIX}" ] || fail "Failed to get prefix from cronjob"

  TEST_DATA_PREFIX="${PREFIX}/$(date +"%Y%m%d")/$(uuid)"
  export TEST_DATA_PREFIX
}

teardown_file() {
  object_storage.delete "${BUCKET}" "${TEST_DATA_PREFIX}"

  kubectl -n "${NAMESPACE}" patch cronjob "${CRONJOB_NAME}" -p '{"spec" : {"suspend" : false}}'
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_detik

  load_common "object-storage.bash"
  load_common "yq.bash"

  with_kubeconfig sc
  with_namespace fluentd-system
}

@test "audit-wc - log-manager compaction job compacts logs" {
  _create_uncompacted_objects

  object_storage.is_not_compacted "${BUCKET}" "${PREFIX}"

  # TODO: This can take a long time. During testing it's been seen running for
  #       over 10 minutes. Giving it 20 minutes timeout for now, however that
  #       is still no guarantee.
  test_run_cronjob "${CRONJOB_NAME}" 1200

  local -r cutoff="$(_get_latest_job_start_time)"

  object_storage.is_compacted "${BUCKET}" "${PREFIX}" "${cutoff}"
}

@test "audit-wc - log-manager compaction job runs fine when no logs need compaction" {
  local -r cutoff="$(_get_latest_job_start_time)"

  object_storage.is_compacted "${BUCKET}" "${PREFIX}" "${cutoff}"

  test_run_cronjob "${CRONJOB_NAME}" 120
}

_create_uncompacted_objects() {
  local test_data_file_1
  local test_data_file_2

  test_data_file_1="${BATS_TEST_TMPDIR}/$(uuid).gz"
  test_data_file_2="${BATS_TEST_TMPDIR}/$(uuid).gz"

  echo 1 | gzip >"${test_data_file_1}"
  echo 2 | gzip >"${test_data_file_2}"

  object_storage.upload "${BUCKET}" "${TEST_DATA_PREFIX}/$(basename "${test_data_file_1}")" "${test_data_file_1}"
  object_storage.upload "${BUCKET}" "${TEST_DATA_PREFIX}/$(basename "${test_data_file_2}")" "${test_data_file_2}"
}

_get_cronjob_env() {
  kubectl -n "${NAMESPACE}" get cronjob "${CRONJOB_NAME}" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].env[?(@.name=="'"${1}"'")].value}'
}

_get_latest_job_start_time() {
  kubectl -n "${NAMESPACE}" get jobs -o json |
    jq -r "[.items[] | select(.metadata.ownerReferences[]?.name==\"${CRONJOB_NAME}\")] | sort_by(.status.startTime) | .[-1].status.startTime"
}
