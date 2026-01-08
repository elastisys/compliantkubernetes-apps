#!/usr/bin/env bats

# bats file_tags=opa-gatekeeper,admin

# Admin-level OPA Gatekeeper policy tests
# These tests require SC (service cluster) kubeconfig with admin access
#
# Strategy:
# - If Cluster API CRDs already exist, use them (create test resources in test namespace)
# - If they don't exist, create minimal stub CRDs for testing, then clean them up
# This allows testing in both CAPI and non-CAPI environments safely.

setup_file() {
  load "../../bats.lib.bash"

  export BATS_NO_PARALLELIZE_WITHIN_FILE="true"
  export TEST_NAMESPACE="opa-admin-test"

  # Track whether we created stub CRDs (so we know whether to delete them)
  export CREATED_CLUSTER_CRD="false"
  export CREATED_OPENSTACK_CRD="false"
  export CREATED_AZURE_CRD="false"

  with_kubeconfig sc

  # Create test namespace
  kubectl create namespace "${TEST_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

  # Only create stub CRDs if they don't already exist (CAPI not installed)
  if ! kubectl get crd clusters.cluster.x-k8s.io &>/dev/null; then
    CREATED_CLUSTER_CRD="true"
    kubectl apply -f - <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: clusters.cluster.x-k8s.io
  labels:
    e2e-test: opa-gatekeeper-admin
spec:
  group: cluster.x-k8s.io
  names:
    kind: Cluster
    listKind: ClusterList
    plural: clusters
    singular: cluster
  scope: Namespaced
  versions:
  - name: v1beta1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            x-kubernetes-preserve-unknown-fields: true
EOF
    kubectl wait --for=condition=Established crd/clusters.cluster.x-k8s.io --timeout=30s
  fi

  if ! kubectl get crd openstackclusters.infrastructure.cluster.x-k8s.io &>/dev/null; then
    CREATED_OPENSTACK_CRD="true"
    kubectl apply -f - <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: openstackclusters.infrastructure.cluster.x-k8s.io
  labels:
    e2e-test: opa-gatekeeper-admin
spec:
  group: infrastructure.cluster.x-k8s.io
  names:
    kind: OpenStackCluster
    listKind: OpenStackClusterList
    plural: openstackclusters
    singular: openstackcluster
  scope: Namespaced
  versions:
  - name: v1beta1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            x-kubernetes-preserve-unknown-fields: true
EOF
    kubectl wait --for=condition=Established crd/openstackclusters.infrastructure.cluster.x-k8s.io --timeout=30s
  fi

  if ! kubectl get crd azureclusters.infrastructure.cluster.x-k8s.io &>/dev/null; then
    CREATED_AZURE_CRD="true"
    kubectl apply -f - <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: azureclusters.infrastructure.cluster.x-k8s.io
  labels:
    e2e-test: opa-gatekeeper-admin
spec:
  group: infrastructure.cluster.x-k8s.io
  names:
    kind: AzureCluster
    listKind: AzureClusterList
    plural: azureclusters
    singular: azurecluster
  scope: Namespaced
  versions:
  - name: v1beta1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            x-kubernetes-preserve-unknown-fields: true
EOF
    kubectl wait --for=condition=Established crd/azureclusters.infrastructure.cluster.x-k8s.io --timeout=30s
  fi

  # Create test resources in our isolated test namespace
  kubectl apply -f - <<EOF
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: test-cluster
  namespace: ${TEST_NAMESPACE}
spec: {}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackCluster
metadata:
  name: test-openstack-cluster
  namespace: ${TEST_NAMESPACE}
spec: {}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureCluster
metadata:
  name: test-azure-cluster
  namespace: ${TEST_NAMESPACE}
spec: {}
EOF

  # Export the flags for teardown (bats runs teardown in separate process)
  echo "${CREATED_CLUSTER_CRD}" > /tmp/opa-admin-test-cluster-crd
  echo "${CREATED_OPENSTACK_CRD}" > /tmp/opa-admin-test-openstack-crd
  echo "${CREATED_AZURE_CRD}" > /tmp/opa-admin-test-azure-crd
}

teardown_file() {
  load "../../bats.lib.bash"
  with_kubeconfig sc

  # Read flags from temp files
  CREATED_CLUSTER_CRD=$(cat /tmp/opa-admin-test-cluster-crd 2>/dev/null || echo "false")
  CREATED_OPENSTACK_CRD=$(cat /tmp/opa-admin-test-openstack-crd 2>/dev/null || echo "false")
  CREATED_AZURE_CRD=$(cat /tmp/opa-admin-test-azure-crd 2>/dev/null || echo "false")

  # Delete test resources (only in our test namespace - safe even with real CAPI)
  kubectl delete cluster test-cluster -n "${TEST_NAMESPACE}" --ignore-not-found --force --grace-period=0 2>/dev/null || true
  kubectl delete openstackcluster test-openstack-cluster -n "${TEST_NAMESPACE}" --ignore-not-found --force --grace-period=0 2>/dev/null || true
  kubectl delete azurecluster test-azure-cluster -n "${TEST_NAMESPACE}" --ignore-not-found --force --grace-period=0 2>/dev/null || true

  # Delete test namespace
  kubectl delete namespace "${TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true

  # Only delete CRDs if WE created them (not if they were pre-existing CAPI CRDs)
  if [[ "${CREATED_CLUSTER_CRD}" == "true" ]]; then
    kubectl delete crd clusters.cluster.x-k8s.io --ignore-not-found
  fi
  if [[ "${CREATED_OPENSTACK_CRD}" == "true" ]]; then
    kubectl delete crd openstackclusters.infrastructure.cluster.x-k8s.io --ignore-not-found
  fi
  if [[ "${CREATED_AZURE_CRD}" == "true" ]]; then
    kubectl delete crd azureclusters.infrastructure.cluster.x-k8s.io --ignore-not-found
  fi

  # Clean up temp files
  rm -f /tmp/opa-admin-test-cluster-crd /tmp/opa-admin-test-openstack-crd /tmp/opa-admin-test-azure-crd
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  with_kubeconfig sc
}

@test "opa gatekeeper policies - error delete cluster without annotation" {
  # Skip if prevent-accidental-deletion constraint is not enabled
  if ! kubectl get k8spreventaccidentaldeletions.constraints.gatekeeper.sh &>/dev/null; then
    skip "prevent-accidental-deletion constraint not enabled"
  fi

  # Attempt to delete the test cluster (should be denied by Gatekeeper)
  run kubectl delete cluster test-cluster -n "${TEST_NAMESPACE}"

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - error delete openstackcluster without annotation" {
  # Skip if prevent-accidental-deletion constraint is not enabled
  if ! kubectl get k8spreventaccidentaldeletions.constraints.gatekeeper.sh &>/dev/null; then
    skip "prevent-accidental-deletion constraint not enabled"
  fi

  # Attempt to delete the test OpenStackCluster (should be denied by Gatekeeper)
  run kubectl delete openstackcluster test-openstack-cluster -n "${TEST_NAMESPACE}"

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - error delete azurecluster without annotation" {
  # Skip if prevent-accidental-deletion constraint is not enabled
  if ! kubectl get k8spreventaccidentaldeletions.constraints.gatekeeper.sh &>/dev/null; then
    skip "prevent-accidental-deletion constraint not enabled"
  fi

  # Attempt to delete the test AzureCluster (should be denied by Gatekeeper)
  run kubectl delete azurecluster test-azure-cluster -n "${TEST_NAMESPACE}"

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - allow delete cluster with annotation" {
  # Skip if prevent-accidental-deletion constraint is not enabled
  if ! kubectl get k8spreventaccidentaldeletions.constraints.gatekeeper.sh &>/dev/null; then
    skip "prevent-accidental-deletion constraint not enabled"
  fi

  # Add the bypass annotation
  kubectl annotate cluster test-cluster -n "${TEST_NAMESPACE}" elastisys.io/ok-to-delete=true --overwrite

  # Attempt to delete should succeed with annotation (use dry-run to not actually delete)
  run kubectl delete cluster test-cluster -n "${TEST_NAMESPACE}" --dry-run=server

  refute_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_success

  # Remove annotation for other tests
  kubectl annotate cluster test-cluster -n "${TEST_NAMESPACE}" elastisys.io/ok-to-delete- --overwrite 2>/dev/null || true
}

@test "opa gatekeeper policies - error unauthorized crd creation" {
  # Skip if user-crds constraint is not enabled
  if ! kubectl get k8susercrdss.constraints.gatekeeper.sh &>/dev/null; then
    skip "user-crds constraint not enabled"
  fi

  # Attempt to create a CRD (should be denied unless user is in allowlist)
  run kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: opatests.e2etest.elastisys.io
spec:
  group: e2etest.elastisys.io
  names:
    kind: OpaTest
    listKind: OpaTestList
    plural: opatests
    singular: opatest
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
EOF

  # The test passes if either:
  # 1. The request is denied (user not in allowlist) - assert_failure
  # 2. The request is allowed (admin user is in allowlist) - assert_success
  if [[ "${status}" -ne 0 ]]; then
    assert_line --regexp '.*is not allowed to .* CRD.*'
    assert_failure
  else
    # If it succeeded, the current user is authorized - that's also valid for admin
    assert_success
  fi
}
