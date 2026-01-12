#!/usr/bin/env bats

# bats file_tags=opa-gatekeeper

# OPA Gatekeeper E2E tests for cluster-level policies (CAPI + CRD policies).
# Uses admin@example.com (cluster-admin) authentication via OIDC/Cypress.

setup_file() {
  load "../../bats.lib.bash"

  export BATS_NO_PARALLELIZE_WITHIN_FILE="true"

  # Namespace for cluster-level policy tests (only used when CAPI is available)
  export ADMIN_TEST_NAMESPACE="opa-admin-test"

  # Authenticate as admin@example.com (cluster-admin) via OIDC/Cypress
  with_static_wc_kubeconfig admin
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_detik
}

teardown_file() {
  load "../../bats.lib.bash"

  # Clean up kubeconfig
  delete_static_wc_kubeconfig admin
}

# ============================================
# Cluster-level policy tests (CAPI)
# These tests are skipped when Cluster API is not installed
# ============================================

@test "opa gatekeeper policies - error delete cluster without annotation" {
  # Skip if CAPI Cluster CRD is not installed
  if ! kubectl get crd clusters.cluster.x-k8s.io &>/dev/null; then
    skip "Cluster API not installed (clusters.cluster.x-k8s.io CRD not found)"
  fi

  # Create test namespace and resource
  kubectl create namespace "${ADMIN_TEST_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f - <<EOF
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: test-cluster
  namespace: ${ADMIN_TEST_NAMESPACE}
spec: {}
EOF

  # Attempt to delete the test cluster (should be denied by Gatekeeper)
  run kubectl delete cluster test-cluster -n "${ADMIN_TEST_NAMESPACE}"

  # Cleanup (force delete with annotation)
  kubectl annotate cluster test-cluster -n "${ADMIN_TEST_NAMESPACE}" elastisys.io/ok-to-delete=true --overwrite 2>/dev/null || true
  kubectl delete cluster test-cluster -n "${ADMIN_TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true
  kubectl delete namespace "${ADMIN_TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - error delete openstackcluster without annotation" {
  # Skip if CAPI OpenStackCluster CRD is not installed
  if ! kubectl get crd openstackclusters.infrastructure.cluster.x-k8s.io &>/dev/null; then
    skip "Cluster API OpenStack provider not installed (openstackclusters CRD not found)"
  fi

  # Create test namespace and resource
  kubectl create namespace "${ADMIN_TEST_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f - <<EOF
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackCluster
metadata:
  name: test-openstack-cluster
  namespace: ${ADMIN_TEST_NAMESPACE}
spec: {}
EOF

  # Attempt to delete the test OpenStackCluster (should be denied by Gatekeeper)
  run kubectl delete openstackcluster test-openstack-cluster -n "${ADMIN_TEST_NAMESPACE}"

  # Cleanup (force delete with annotation)
  kubectl annotate openstackcluster test-openstack-cluster -n "${ADMIN_TEST_NAMESPACE}" elastisys.io/ok-to-delete=true --overwrite 2>/dev/null || true
  kubectl delete openstackcluster test-openstack-cluster -n "${ADMIN_TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true
  kubectl delete namespace "${ADMIN_TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - error delete azurecluster without annotation" {
  # Skip if CAPI AzureCluster CRD is not installed
  if ! kubectl get crd azureclusters.infrastructure.cluster.x-k8s.io &>/dev/null; then
    skip "Cluster API Azure provider not installed (azureclusters CRD not found)"
  fi

  # Create test namespace and resource
  kubectl create namespace "${ADMIN_TEST_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f - <<EOF
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureCluster
metadata:
  name: test-azure-cluster
  namespace: ${ADMIN_TEST_NAMESPACE}
spec: {}
EOF

  # Attempt to delete the test AzureCluster (should be denied by Gatekeeper)
  run kubectl delete azurecluster test-azure-cluster -n "${ADMIN_TEST_NAMESPACE}"

  # Cleanup (force delete with annotation)
  kubectl annotate azurecluster test-azure-cluster -n "${ADMIN_TEST_NAMESPACE}" elastisys.io/ok-to-delete=true --overwrite 2>/dev/null || true
  kubectl delete azurecluster test-azure-cluster -n "${ADMIN_TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true
  kubectl delete namespace "${ADMIN_TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - allow delete cluster with annotation" {
  # Skip if CAPI Cluster CRD is not installed
  if ! kubectl get crd clusters.cluster.x-k8s.io &>/dev/null; then
    skip "Cluster API not installed (clusters.cluster.x-k8s.io CRD not found)"
  fi

  # Create test namespace and resource with the bypass annotation
  kubectl create namespace "${ADMIN_TEST_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f - <<EOF
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: test-cluster
  namespace: ${ADMIN_TEST_NAMESPACE}
  annotations:
    elastisys.io/ok-to-delete: "true"
spec: {}
EOF

  # Attempt to delete should succeed with annotation (use dry-run to not actually delete)
  run kubectl delete cluster test-cluster -n "${ADMIN_TEST_NAMESPACE}" --dry-run=server

  # Cleanup
  kubectl delete cluster test-cluster -n "${ADMIN_TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true
  kubectl delete namespace "${ADMIN_TEST_NAMESPACE}" --ignore-not-found 2>/dev/null || true

  refute_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_success
}

@test "opa gatekeeper policies - error unauthorized crd creation" {
  local -r test_user="opa-unlisted@example.com"
  local -r rbac_name="opa-user-crd-test"

  # Grant CRD create permission so Gatekeeper (not RBAC) does the denial.
  kubectl create clusterrole "${rbac_name}" \
    --verb=create \
    --resource=customresourcedefinitions.apiextensions.k8s.io \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl create clusterrolebinding "${rbac_name}" \
    --clusterrole="${rbac_name}" \
    --user="${test_user}" \
    --dry-run=client -o yaml | kubectl apply -f -

  # Attempt to create a CRD (should be denied because user is not in allowlist)
  run kubectl apply --dry-run=server --as="${test_user}" -f - <<'EOF'
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

  # Cleanup
  kubectl delete clusterrolebinding "${rbac_name}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete clusterrole "${rbac_name}" --ignore-not-found >/dev/null 2>&1 || true

  assert_line --regexp '.*is not allowed to .* CRD.*'
  assert_failure
}
