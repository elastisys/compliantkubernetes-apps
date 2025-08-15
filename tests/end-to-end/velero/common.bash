# Usage: velero_backups_spec_without_excluded_namespaces <cluster>
velero_backups_spec_without_excluded_namespaces() {
  ck8s ops velero "${1}" backup create --from-schedule velero-daily-backup -o yaml 2>/dev/null | yq '.spec | del(.excludedNamespaces)'
}

# Usage: velero_backups_excluded_namespaces <cluster>
velero_backups_excluded_namespaces() {
  ck8s ops velero "${1}" backup create --from-schedule velero-daily-backup -o yaml 2>/dev/null | yq '.spec.excludedNamespaces'
}

# Usage: velero_expected_spec_without_excluded_namespaces <cluster>
velero_expected_spec_without_excluded_namespaces() {
  yq 'del(.excludedNamespaces)' <"${BATS_TEST_DIRNAME}/resources/backup-spec-${1}.yaml"
}

# Usage: velero_expected_excluded_namespaces <cluster>
velero_expected_excluded_namespaces() {
  yq '.excludedNamespaces' <"${BATS_TEST_DIRNAME}/resources/backup-spec-${1}.yaml"
}

# Usage: velero_backup_create <cluster> <backup_name>
velero_backup_create() {
  ck8s ops velero "${1}" backup create "${2}" --from-schedule velero-daily-backup --wait
}

# Usage: velero_backup_get_phase <cluster> <backup_name>
velero_backup_get_phase() {
  ck8s ops velero "${1}" backup get "${2}" -o json 2>/dev/null | jq -r .status.phase
}

# Usage: velero_restore_create <cluster> <backup_name>
velero_restore_create() {
  ck8s ops velero "${1}" restore create "${2}" --from-backup "${3}" --wait
}

# Usage: velero_restore_get_phase <cluster> <backup_name>
velero_restore_get_phase() {
  ck8s ops velero "${1}" restore get "${2}" -o json 2>/dev/null | jq -r .status.phase
}
