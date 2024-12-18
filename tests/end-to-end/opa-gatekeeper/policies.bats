#!/usr/bin/env bats

# Tests opa gatekeeper policies

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE="true"
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"
  load_common "harbor.bash"
  load_common "yq.bash"
  load_assert

  skip "needs reimplementation"

  harbor.load_env gatekeeper-policies
  harbor.setup_project
  harbor.setup_user_demo_image

  export harbor_endpoint

  export user_demo_chart="${DOCS_PATH}/user-demo/deploy/ck8s-user-demo"
  export user_demo_image

  if ! docker pull "${user_demo_image}"; then
    fail "unable to pull image from harbor"
  fi

  with_kubeconfig wc

  if ! kubectl get ns staging &>/dev/null || [[ "$(kubectl get ns staging '-ojsonpath={.metadata.labels.owner}')" == "operator" ]]; then
    fail "these tests requires that you have a 'staging' user namespace"
  fi

  harbor.create_pull_secret wc staging
}

teardown_file() {
  load "../../bats.lib.bash"
  load_common "harbor.bash"
  load_assert

  # harbor.delete_pull_secret wc staging
  # harbor.teardown_project
}

setup() {
  load "../bats.lib.bash"
  load_assert

  with_kubeconfig wc
  with_namespace staging
}

@test "opa gatekeeper policies - warn invalid image repository" {
  run helm -n "${NAMESPACE}" upgrade --install opa-image-repository "${user_demo_chart}" \
    --set "image.repository=not-${harbor_endpoint}/non-existing-repository" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "ingress.enabled=false"

  helm -n "${NAMESPACE}" uninstall opa-image-repository --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=ck8s-user-demo,app.kubernetes.io/instance=opa-image-repository

  assert_line --regexp '.*does not have an allowed image registry.*'
  assert_success
}

@test "opa gatekeeper policies - error invalid image tag" {
  run helm -n "${NAMESPACE}" upgrade --atomic --install opa-image-tag "${user_demo_chart}" \
    --set "image.repository=${user_demo_image#:.*}" \
    --set "image.tag=latest" \
    --set "ingress.enabled=false"

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*uses the :latest tag.*'
  assert_failure
}

@test "opa gatekeeper policies - warn missing networkpolicies" {
  run helm -n "${NAMESPACE}" upgrade --install opa-networkpolicies "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "networkPolicy.enabled=false" \
    --set "ingress.enabled=false"

  helm -n "${NAMESPACE}" uninstall opa-networkpolicies --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=ck8s-user-demo,app.kubernetes.io/instance=opa-networkpolicies

  assert_line --regexp '.*No matching networkpolicy found.*'
  assert_success
}

@test "opa gatekeeper policies - error missing resources" {
  run helm -n "${NAMESPACE}" upgrade --atomic --install opa-resources "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "resources=null" \
    --set "ingress.enabled=false"

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*The container named .* has no resource requests.*'
  assert_failure
}

@test "opa gatekeeper policies - allow and mutate valid deployment" {
  run helm -n "${NAMESPACE}" upgrade --atomic --install opa-valid "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "ingress.enabled=false"

  refute_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  refute_line --regexp '.*does not have an allowed image registry.*'
  refute_line --regexp '.*uses the :latest tag.*'
  refute_line --regexp '.*No matching networkpolicy found.*'
  refute_line --regexp '.*The container named .* has no resource requests.*'
  assert_line --regexp '.*would violate PodSecurity "restricted:latest".*'
  assert_success

  test_deployment opa-valid-ck8s-user-demo 2

  helm -n "${NAMESPACE}" uninstall opa-valid --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=ck8s-user-demo,app.kubernetes.io/instance=opa-valid
}
