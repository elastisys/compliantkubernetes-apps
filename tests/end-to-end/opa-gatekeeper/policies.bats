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

@test "opa gatekeeper policies - error insufficient replicas" {
  run helm -n "${NAMESPACE}" upgrade --atomic --install opa-replicas "${user_demo_chart}" \
    --set "image.repository=${user_demo_image%:*}" \
    --set "image.tag=${user_demo_image#*:}" \
    --set "replicaCount=1" \
    --set "ingress.enabled=false"

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*The provided number of replicas is too low.*'
  assert_failure
}

@test "opa gatekeeper policies - error loadbalancer service" {
  run kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: opa-loadbalancer-test
  namespace: ${NAMESPACE}
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: welkin-user-demo
    app.kubernetes.io/instance: test
  ports:
  - port: 80
    targetPort: 8080
EOF

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*Creation of LoadBalancer Service is not supported.*'
  assert_failure

  # Clean up
  kubectl -n "${NAMESPACE}" delete svc opa-loadbalancer-test --ignore-not-found
}

@test "opa gatekeeper policies - error localhost seccomp" {
  run kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: opa-seccomp-test
  namespace: ${NAMESPACE}
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profile.json
  containers:
  - name: test
    image: ${user_demo_image}
EOF

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*localhost seccomp profile.*'
  assert_failure

  # Clean up
  kubectl -n "${NAMESPACE}" delete pod opa-seccomp-test --ignore-not-found
}

@test "opa gatekeeper policies - warn accidental deletion" {
  # This test would require creating Cluster resources which is complex in e2e
  # For now, we'll skip this test as it requires cluster-level resources
  skip "Cluster-level resources test - requires cluster admin access"
}

@test "opa gatekeeper policies - error local storage empty dir" {
  run kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: opa-storage-test
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: test
    image: ${user_demo_image}
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    emptyDir: {}
EOF

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*emptyDir or local storage.*'
  assert_failure

  # Clean up
  kubectl -n "${NAMESPACE}" delete pod opa-storage-test --ignore-not-found
}

@test "opa gatekeeper policies - error pod without controller" {
  run kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: opa-standalone-test
  namespace: ${NAMESPACE}
spec:
  containers:
  - name: test
    image: ${user_demo_image}
EOF

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*Pod without controller.*'
  assert_failure

  # Clean up
  kubectl -n "${NAMESPACE}" delete pod opa-standalone-test --ignore-not-found
}

@test "opa gatekeeper policies - error pod disruption budgets outside allowed namespaces" {
  run kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: opa-pdb-test
  namespace: ${NAMESPACE}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: test
EOF

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*PodDisruptionBudget not allowed.*'
  assert_failure

  # Clean up
  kubectl -n "${NAMESPACE}" delete pdb opa-pdb-test --ignore-not-found
}

@test "opa gatekeeper policies - error non-whitelisted CRDs" {
  run kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: testcrds.example.com
spec:
  group: example.com
  versions:
  - name: v1
    served: true
    storage: true
  scope: Namespaced
  names:
    plural: testcrds
    singular: testcrd
    kind: TestCRD
EOF

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*CRD not whitelisted.*'
  assert_failure

  # Clean up
  kubectl delete crd testcrds.example.com --ignore-not-found
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
  assert_success

  test_deployment opa-valid-welkin-user-demo 2

  helm -n "${NAMESPACE}" uninstall opa-valid --wait
  kubectl -n "${NAMESPACE}" delete po -l app.kubernetes.io/name=welkin-user-demo,app.kubernetes.io/instance=opa-valid
}
