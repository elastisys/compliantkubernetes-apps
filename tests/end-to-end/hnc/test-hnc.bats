#!/usr/bin/env bats

# bats file_tags=hnc

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export CK8S_AUTO_APPROVE="true"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  with_namespace staging
}

@test "hnc dev can create subnamespace" {
  with_test_kubeconfig wc static-dev
  echo "# If the test stops here go to http://localhost:8000 and log in with static email user dev@example.com" >&3
  run kubectl auth whoami
  assert_output --partial "dev@example.com"
  run kubectl apply -f - <<EOF
apiVersion: hnc.x-k8s.io/v1alpha2
kind: SubnamespaceAnchor
metadata:
  name: "${NAMESPACE}-tests-end-to-end"
  namespace: "${NAMESPACE}"
EOF

  assert_success
}

@test "hnc subnamespace can create namespace" {
  with_test_kubeconfig wc static-dev
  echo "# If the test stops here go to http://localhost:8000 and log in with static email user dev@example.com" >&3
  run kubectl auth whoami
  assert_output --partial "dev@example.com"
  run kubectl get ns "${NAMESPACE}"-tests-end-to-end
  assert_success
}

check_resources_exist() {
  local resource=$1
  local missing=""

  local base_list
  local target_list

  base_list=$(kubectl get "$resource" -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)
  target_list=$(kubectl get "$resource" -n "${NAMESPACE}"-tests-end-to-end -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)

  missing=$(comm -23 <(echo "$base_list") <(echo "$target_list") || true)

  if [[ -n "$missing" ]]; then
    echo "Missing $resource in ${NAMESPACE}-tests-end-to-end:"
    echo "$missing"
    return 1
  fi

  return 0
}

@test "hnc subnamespace can propagate roles" {
  run check_resources_exist roles
  assert_success
}

@test "hnc subnamespace can propagate rolebindings" {
  run check_resources_exist rolebindings
  assert_success
}

@test "hnc subnamespace can propagate networkpolicies" {
  run check_resources_exist netpol
  assert_success
}

@test "hnc dev can delete subnamespace" {
  with_test_kubeconfig wc static-dev
  echo "# If the test stops here go to http://localhost:8000 and log in with static email user dev@example.com" >&3
  run kubectl delete subns "${NAMESPACE}"-tests-end-to-end --namespace "${NAMESPACE}"
  assert_success
}

@test "hnc subnamespace can delete namespace" {
  with_test_kubeconfig wc static-dev
  echo "# If the test stops here go to http://localhost:8000 and log in with static email user dev@example.com" >&3
  # Check if the namespace still exists (it should NOT)
  run kubectl get ns "${NAMESPACE}"-tests-end-to-end
  [ "$status" -ne 0 ]
}
