#!/usr/bin/env bats

# Generated from tests/end-to-end/log-manager/retention.bats.gotmpl

# bats file_tags=log-manager,sc-logs

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

  CRONJOB_NAME="sc-logs-logs-retention"
  export CRONJOB_NAME

  # TODO: Should probably make sure that the cronjob isn't currently running.
  kubectl -n "${NAMESPACE}" patch cronjob "${CRONJOB_NAME}" -p '{"spec" : {"suspend" : true}}'

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

  TEST_DATA_PREFIX="${PREFIX}/19991231"
  export TEST_DATA_PREFIX
  TEST_DATA_FILE="$(uuid).gz"
  export TEST_DATA_FILE
}

teardown_file() {
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

@test "sc-logs - log-manager retention job deletes old logs" {
  echo 1 | gzip >"${BATS_TEST_TMPDIR}/${TEST_DATA_FILE}"

  object_storage.upload "${BUCKET}" "${TEST_DATA_PREFIX}/${TEST_DATA_FILE}" "${BATS_TEST_TMPDIR}/${TEST_DATA_FILE}"

  object_storage.has "${BUCKET}" "${TEST_DATA_PREFIX}"

  test_run_cronjob "${CRONJOB_NAME}" 300

  # TODO: This could be improved to make sure that _all_ objects that should
  #       have been deleted has been deleted. Now it only verifies that the
  #       test data is deleted by the retention job.
  object_storage.has_none "${BUCKET}" "${TEST_DATA_PREFIX}"
}

@test "sc-logs - log-manager retention job runs fine when no logs needs to be deleted" {
  test_run_cronjob "${CRONJOB_NAME}" 120
}

_get_cronjob_env() {
  kubectl -n "${NAMESPACE}" get cronjob "${CRONJOB_NAME}" -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].env[?(@.name=="'"${1}"'")].value}'
}
