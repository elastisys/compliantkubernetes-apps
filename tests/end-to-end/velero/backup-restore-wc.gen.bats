#!/usr/bin/env bats

# Generated from tests/end-to-end/velero/backup-restore.bats.gotmpl

setup() {
  load "../../bats.lib.bash"
  load_assert
  load "./common.bash"
}

@test "velero backup spec wc" {
  run velero_backups_spec wc
  assert_success
  assert_output "$(cat "${BATS_TEST_DIRNAME}/resources/backup-spec-wc.yaml")"
}

@test "velero backup and restore wc" {
  backup_name="test-backup-$(date +%s)"
  restore_name="test-restore-$(date +%s)"

  run velero_backup_create wc "${backup_name}"
  assert_success

  run velero_backup_get_phase wc "${backup_name}"
  assert_success
  assert_output Completed

  run velero_restore_create wc "${restore_name}" "${backup_name}"
  assert_success

  run velero_restore_get_phase wc "${restore_name}"
  assert_success
  assert_output Completed
}
