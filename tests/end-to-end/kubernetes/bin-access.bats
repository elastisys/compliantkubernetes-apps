#!/usr/bin/env bats

# bats file_tags=kubernetes

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_file

  export CK8S_AUTO_APPROVE=true
  CK8S_PGP_FP=$(yq '.creation_rules[].pgp' "${CK8S_CONFIG_PATH}/.sops.yaml")
  export CK8S_PGP_FP
}

teardown() {
  delete_test_kubeconfig wc static-dev
}

@test "static user can list access" {
  with_test_kubeconfig wc static-dev
  echo "# If cypress auth tests were run previously, test should continue automatically. Otherwise, go to http://localhost:8000 and log in with static email user dev@example.com" >&3
  run kubectl auth whoami
  assert_output --partial "dev@example.com"
  run kubectl -n staging auth can-i --list
  assert_success
}

@test "static user can delegate admin access" {
  with_test_kubeconfig wc static-dev
  run kubectl auth whoami
  assert_output --partial "dev@example.com"
  run kubectl -n staging patch rolebinding extra-workload-admins -p '{"subjects":[{"apiGroup":"rbac.authorization.k8s.io","kind":"User","name":"jane"}]}'
  assert_success
}

@test "static user can delegate view access" {
  with_test_kubeconfig wc static-dev
  run kubectl auth whoami
  assert_output --partial "dev@example.com"
  run kubectl patch clusterrolebinding extra-user-view -p '{"subjects":[{"apiGroup":"rbac.authorization.k8s.io","kind":"User","name":"jane"}]}'
  assert_success
}

@test "static user cannot run pod as root" {
  with_test_kubeconfig wc static-dev
  run kubectl auth whoami
  assert_output --partial "dev@example.com"
  kubectl delete --ignore-not-found -n staging -f "${APPS_PATH}/tests/end-to-end/kubernetes/allow-root-nginx.yaml"
  kubectl apply -n staging -f "${APPS_PATH}/tests/end-to-end/kubernetes/allow-root-nginx.yaml"
  run kubectl wait --for=jsonpath='{.status.containerStatuses[0].state.waiting.reason}=CreateContainerConfigError' -n staging pod/root-nginx --timeout=60s

  assert_output "pod/root-nginx condition met"
  kubectl delete --ignore-not-found -n staging -f "${APPS_PATH}/tests/end-to-end/kubernetes/allow-root-nginx.yaml"
}
