#!/usr/bin/env bats

# Generated from tests/end-to-end/fluentd/audit.bats.gotmpl

# bats file_tags=fluentd,sc

set -o pipefail

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true

  load "../../bats.lib.bash"

  load_common "object-storage.bash"
  load_common "yq.bash"

  object_storage.load_env
}

setup() {
  load "../../bats.lib.bash"
  load_assert

  load_common "object-storage.bash"
  load_common "yq.bash"
}

@test "fluentd forwards audit logs to object storage" {
  local bucket
  bucket="$(yq.get sc '.objectStorage.buckets.audit')"
  local prefix
  prefix="$(yq.get sc '.global.clusterName')/$(date +"%Y%m%d")/kubeaudit.var.log.kubernetes.audit.kube-apiserver-audit.log"

  local destination="${BATS_TEST_TMPDIR}/audit-logs"
  mkdir "${destination}"

  object_storage.download_one "${bucket}" "${prefix}" "${destination}"

  run _count_audit_log_events "${destination}"
  assert_success
  [ "${output}" -gt 0 ]
}

_count_audit_log_events() {
  {
    find "${1}" -type f \( -name "*.gz" -o -name "*.zst" \) -print0 | while IFS= read -r -d '' file; do
      case "${file}" in
      *.gz) zcat "${file}" ;;
      *.zst) unzstd --stdout "${file}" ;;
      esac
    done
  } | cut -d $'\t' -f 3 | jq --slurp 'map(select(.kind == "Event")) | length'
}
