#!/usr/bin/env bash

# Helpers for interacting with object storage:
# - object_storage.load_env                                     - setup necessary variables for the object storage helper functions
# - object_storage.wait [bucket] [prefix] [timeout in seconds]  - wait for at least one object to exists
# - object_storage.download [bucket] [prefix] [destination]     - download objects recursively
# - object_storage.download_one [bucket] [prefix] [destination] - download the first object found

object_storage.load_env() {
  local object_storage_type
  object_storage_type="$(yq.get sc '.objectStorage.type')"
  case "${object_storage_type}" in
  "s3")
    # No special setup needed
    ;;
  "azure")
    # TODO: Maybe create a dedicated command similar to `ck8s s3cmd`?
    AZURE_STORAGE_ACCOUNT="$(yq.get sc '.objectStorage.azure.storageAccountName')"
    export AZURE_STORAGE_ACCOUNT
    AZURE_STORAGE_KEY="$(yq.secret '.objectStorage.azure.storageAccountKey')"
    export AZURE_STORAGE_KEY
    ;;
  *)
    fail "Unsupported object storage type: ${object_storage_type}"
    ;;
  esac
}

object_storage.wait() {
  local bucket="${1}"
  local prefix="${2}"
  local timeout="${3}"

  timeout=$((timeout + SECONDS))
  while [ "${SECONDS}" -lt "${timeout}" ]; do
    run _object_storage_list_one "${bucket}" "${prefix}"
    assert_success
    assert_output --partial "${prefix}" && return
    sleep 1
  done

  fail "timeout when waiting for object storage prefix to appear in bucket '${bucket}': ${prefix}"
}

object_storage.download() {
  local bucket="${1}"
  local prefix="${2}"
  local destination="${3}"

  local object_storage_type
  object_storage_type="$(yq.get sc '.objectStorage.type')"
  case "${object_storage_type}" in
  "s3")
    ck8s s3cmd get --recursive "s3://${bucket}/${prefix}" "${destination}"
    ;;
  "azure")
    az storage blob download-batch --source "${bucket}" --pattern "${prefix}*" --destination "${destination}"
    ;;
  *)
    fail "Unsupported object storage type: ${object_storage_type}"
    ;;
  esac
}

object_storage.download_one() {
  # for --separate-stderr argument on 'run'
  bats_require_minimum_version 1.11.1

  local bucket="${1}"
  local prefix="${2}"
  local destination="${3}"

  run --separate-stderr _object_storage_list_one "${bucket}" "${prefix}"
  assert_success
  assert_output --partial "${prefix}"

  # shellcheck disable=SC2154
  object_storage.download "${bucket}" "${output}" "${destination}"
}

_object_storage_list_one() {
  local bucket="${1}"
  local prefix="${2}"

  local object_storage_type
  object_storage_type="$(yq.get sc '.objectStorage.type')"
  case "${object_storage_type}" in
  "s3")
    ck8s s3cmd ls --limit 1 --recursive "s3://${bucket}/${prefix}" | awk '{print $4}' | sed "s|s3://${bucket}/||"
    ;;
  "azure")
    az storage blob list --num-results 1 --container-name "${bucket}" --prefix "${prefix}" --query '[].name' | jq -r '.[]'
    ;;
  *)
    echo "Unsupported object storage type: ${object_storage_type}" >&2
    return 1
    ;;
  esac
}
