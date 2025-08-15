#!/usr/bin/env bats

# Generated from tests/end-to-end/velero/backup-restore.bats.gotmpl

setup() {
  load "../../bats.lib.bash"
  load_assert
  load "./common.bash"
}

@test "velero backup spec wc" {
  run velero_backups_spec_without_excluded_namespaces wc
  assert_success
  assert_output "$(velero_expected_spec_without_excluded_namespaces wc)"

  # Expect the spec to contain _at least_ the namespaces specified by the fixture
  # (but we don't mind if we find more)
  run comm -13 \
    <(velero_backups_excluded_namespaces wc | sort) \
    <(velero_expected_excluded_namespaces wc | sort)
  refute_output
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
