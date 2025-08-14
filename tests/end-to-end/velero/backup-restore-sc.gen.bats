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
  assert_output "$(velero_expected_spec sc)"

  # Expect the spec to contain _at least_ the namespaces specified by the fixture
  # (but we don't mind if we find more)
  run comm -13 \
    <(velero_backups_excluded_ns sc | sort) \
    <(velero_expected_excluded_ns sc | sort)
  refute_output
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
