#!/usr/bin/env bats

create_test_namespace() {
  kubectl apply -f "${BATS_TEST_DIRNAME}/resources/test-namespace.yaml" --wait
}

wait_test_namespace() {
  kubectl wait --for jsonpath='{.status.phase}'=Active namespace/velero-test
}

delete_test_namespace() {
  kubectl delete -f "${BATS_TEST_DIRNAME}/resources/test-namespace.yaml" --wait
}

create_test_application() {
  image="${1}" envsubst < "${BATS_TEST_DIRNAME}/resources/test-application.yaml" | kubectl apply -f - --wait
}

wait_test_application() {
  kubectl -n velero-test wait --for=condition=Ready pod/velero-test --timeout=120s
}

delete_test_application() {
  kubectl delete -f "${BATS_TEST_DIRNAME}/resources/test-application.yaml" --wait
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_common "yq.bash"
  load_common "ctr.bash"
  load_common "harbor.bash"
  load "./common.bash"

  harbor.load_env velero-test
  harbor.setup_project
  ctr pull alpine:3.20.2
  # Harbor variables are defined in `harbor.load_env`.
  # shellcheck disable=SC2154
  image="${harbor_endpoint}/${harbor_project}/alpine:3.20.2"
  ctr tag alpine:3.20.2 "${image}"
  ctr push "${image}"

  with_kubeconfig wc

  create_test_namespace
  wait_test_namespace

  harbor.create_pull_secret wc velero-test

  create_test_application "${image}"
  wait_test_application
}

teardown() {
  delete_test_application

  delete_test_namespace

  harbor.teardown_project
}

@test "velero backup and restore user application" {
  # TODO: Remove skip when fixed https://github.com/elastisys/compliantkubernetes-apps/issues/2321
  skip "This does not currently work and is a known issue"

  backup_name="test-backup-$(date +%s)"
  restore_name="test-restore-$(date +%s)"

  run kubectl -n velero-test exec velero-test -- touch /test/hello
  assert_success

  run velero_backup_create wc "${backup_name}"
  assert_success

  run velero_backup_get_phase wc "${backup_name}"
  assert_success
  assert_output Completed

  delete_test_application
  delete_test_namespace

  run velero_restore_create wc "${restore_name}" "${backup_name}"
  assert_success

  run velero_restore_get_phase wc "${restore_name}"
  assert_success
  assert_output Completed

  wait_test_namespace
  wait_test_application

  run kubectl -n velero-test exec velero-test -- test -f /test/hello
  assert_success
}
