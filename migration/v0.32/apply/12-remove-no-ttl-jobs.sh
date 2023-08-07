#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

find_delete_no_ttl_jobs() {
  date_7d_ago=$(date --date="7 days ago" -u +"%Y-%m-%dT%H:%M:%SZ")
  export date_7d_ago
  for n in $(kubectl_do "${1}" get ns -o name); do
      n=${n##namespace/}
      for job in $(kubectl_do "${1}" -n "${n}" get jobs -oyaml | yq4 '.items[] | select(.spec.ttlSecondsAfterFinished == null and .status.startTime < strenv(date_7d_ago) and .status.active == null) | .metadata.name'); do
          if [[ "${job}" != "null" ]]; then
              log_info "--- delete job ${job} in namespace ${n}"
              kubectl_do "${1}" delete job "${job}" -n "${n}"
          fi
      done
  done
}

run() {
  case "${1:-}" in
  execute)
    for cluster in sc wc; do
        log_info "--- check if jobs with not ttl exist in ${cluster}"
        find_delete_no_ttl_jobs ${cluster}
    done
    ;;
  rollback)
    log_warn "rollback not implemented"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
