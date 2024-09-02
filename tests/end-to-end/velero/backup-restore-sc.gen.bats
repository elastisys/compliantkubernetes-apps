#!/usr/bin/env bats

# Generated from tests/end-to-end/velero/backup-restore.bats.gotmpl

setup() {
  load "../../bats.lib.bash"
  load_assert
  load "./common.bash"
}

@test "velero backup spec sc" {
  run velero_backups_spec sc
  assert_success
  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/backup-spec-sc.yaml")"
}

@test "velero backup and restore sc" {
  backup_name="test-backup-$(date +%s)"
  restore_name="test-restore-$(date +%s)"

  run velero_backup_create sc "${backup_name}"
  assert_success

  run velero_backup_get_phase sc "${backup_name}"
  assert_success
  assert_output Completed

  run velero_restore_create sc "${restore_name}" "${backup_name}"
  assert_success

  run velero_restore_get_phase sc "${restore_name}"
  assert_success
  assert_output Completed
}
