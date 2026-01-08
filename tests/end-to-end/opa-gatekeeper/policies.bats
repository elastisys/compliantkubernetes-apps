#!/usr/bin/env bats

# bats file_tags=opa-gatekeeper

setup_file() {
  load "../../bats.lib.bash"

  export BATS_NO_PARALLELIZE_WITHIN_FILE="true"
  export user_demo_chart="oci://ghcr.io/elastisys/welkin-user-demo"
  export user_demo_image="ghcr.io/elastisys/user-demo:test"

  with_static_wc_kubeconfig
  if ! [[ $(kubectl get ns staging -o json | jq -r '.metadata.labels["hnc.x-k8s.io/included-namespace"]') == "true" ]]; then
    fail "these tests requires that you have a 'staging' user namespace"
  fi

  if ! skopeo inspect docker://${user_demo_image} >/dev/null 2>&1; then
    fail "unable to find image in ghcr"
  fi
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_detik

  with_namespace staging
}

teardown_file() {
  delete_static_wc_kubeconfig
}

@test "static user can list opa rules" {
  run kubectl auth whoami
  assert_output --partial "dev@example.com"
  run kubectl get constraints
  assert_success
}

@test "opa gatekeeper policies - warn invalid image repository" {
  run helm -n "${NAMESPACE}" upgrade --install opa-image-repository "${user_demo_chart}" \
    --set "image.repository=not-existing/non-existing-repository" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "ingress.enabled=false"
  helm -n "${NAMESPACE}" uninstall opa-image-repository --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=welkin-user-demo,app.kubernetes.io/instance=opa-image-repository

  assert_line --regexp '.*does not have an allowed image registry.*'
  assert_success
}

@test "opa gatekeeper policies - error invalid image tag" {
  run helm -n "${NAMESPACE}" upgrade --atomic --install opa-image-tag "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
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
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=welkin-user-demo,app.kubernetes.io/instance=opa-networkpolicies

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

@test "opa gatekeeper policies - warn minimum replicas" {
  run helm -n "${NAMESPACE}" upgrade --install opa-min-replicas "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "replicaCount=1" \
    --set "ingress.enabled=false"

  helm -n "${NAMESPACE}" uninstall opa-min-replicas --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=welkin-user-demo,app.kubernetes.io/instance=opa-min-replicas

  assert_line --regexp '.*The provided number of replicas is too low.*'
  assert_success
}

@test "opa gatekeeper policies - error localhost seccomp" {
  run helm -n "${NAMESPACE}" upgrade --atomic --install opa-seccomp "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "podSecurityContext.seccompProfile.type=Localhost" \
    --set "podSecurityContext.seccompProfile.localhostProfile=profiles/test.json" \
    --set "ingress.enabled=false"

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*uses Localhost seccompProfile.*'
  assert_failure
}

@test "opa gatekeeper policies - warn loadbalancer service" {
  run helm -n "${NAMESPACE}" upgrade --install opa-loadbalancer "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "service.type=LoadBalancer" \
    --set "ingress.enabled=false"

  helm -n "${NAMESPACE}" uninstall opa-loadbalancer --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=welkin-user-demo,app.kubernetes.io/instance=opa-loadbalancer

  assert_line --regexp '.*Creation of LoadBalancer Service is not supported.*'
  assert_success
}

@test "opa gatekeeper policies - warn local storage emptydir" {
  run kubectl -n "${NAMESPACE}" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: opa-emptydir-test
spec:
  containers:
  - name: test
    image: ${user_demo_image}
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir: {}
EOF

  kubectl -n "${NAMESPACE}" delete pod opa-emptydir-test --ignore-not-found

  assert_line --regexp '.*emptyDir is using local storage emptyDir.*'
  assert_success
}

@test "opa gatekeeper policies - warn pod without controller" {
  run kubectl -n "${NAMESPACE}" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: opa-standalone-pod
spec:
  containers:
  - name: test
    image: ${user_demo_image}
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
EOF

  kubectl -n "${NAMESPACE}" delete pod opa-standalone-pod --ignore-not-found

  assert_line --regexp '.*does not have any ownerReferences.*'
  assert_success
}

@test "opa gatekeeper policies - error restrictive pdb" {
  # First create a deployment
  helm -n "${NAMESPACE}" upgrade --install opa-pdb-deploy "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "replicaCount=2" \
    --set "ingress.enabled=false" \
    --wait

  # Try to create a blocking PDB
  run kubectl -n "${NAMESPACE}" apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: opa-blocking-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app.kubernetes.io/instance: opa-pdb-deploy
EOF

  # Cleanup
  kubectl -n "${NAMESPACE}" delete pdb opa-blocking-pdb --ignore-not-found
  helm -n "${NAMESPACE}" uninstall opa-pdb-deploy --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/instance=opa-pdb-deploy

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*minAvailable should always be lower than replica.*'
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
  refute_line --regexp '.*The provided number of replicas is too low.*'
  refute_line --regexp '.*uses Localhost seccompProfile.*'
  refute_line --regexp '.*Creation of LoadBalancer Service is not supported.*'
  assert_success

  test_deployment opa-valid-welkin-user-demo 2

  helm -n "${NAMESPACE}" uninstall opa-valid --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=welkin-user-demo,app.kubernetes.io/instance=opa-valid
}
