velero_backups_spec() {
  ck8s ops velero "${1}" backup create --from-schedule velero-daily-backup -o yaml 2>/dev/null | yq .spec
}

velero_backup_create() {
  ck8s ops velero "${1}" backup create "${2}" --from-schedule velero-daily-backup --wait
}

velero_backup_get_phase() {
  ck8s ops velero "${1}" backup get "${2}" -o json 2>/dev/null | jq -r .status.phase
}

velero_restore_create() {
  ck8s ops velero "${1}" restore create "${2}" --from-backup "${3}" --wait
}

velero_restore_get_phase() {
  ck8s ops velero "${1}" restore get "${2}" -o json 2>/dev/null | jq -r .status.phase
}
