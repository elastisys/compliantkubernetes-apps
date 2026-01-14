#!/usr/bin/env bats

# bats file_tags=opa-gatekeeper

# OPA Gatekeeper E2E tests for cluster-level policies (CAPI + CRD policies).
# CAPI tests run on SC (where Cluster API manages clusters).
# CRD creation test runs on WC (where user workloads are deployed).

setup_file() {
  load "../../bats.lib.bash"

  export BATS_NO_PARALLELIZE_WITHIN_FILE="true"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_detik
}

# ============================================
# Cluster-level policy tests (CAPI) - Run on SC
# These tests verify that accidental deletion of CAPI resources is prevented.
# Skipped when Cluster API is not installed (optional component).
# ============================================

@test "opa gatekeeper policies - error delete cluster without annotation" {
  with_kubeconfig sc
  with_namespace opa-admin-test

  # Skip if CAPI Cluster CRD is not installed (optional component)
  if ! kubectl get crd clusters.cluster.x-k8s.io &>/dev/null; then
    skip "Cluster API not installed (clusters.cluster.x-k8s.io CRD not found)"
  fi

  # Create test namespace and resource
  create_namespace
  kubectl apply -f - <<EOF
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: test-cluster
  namespace: ${NAMESPACE}
spec: {}
EOF

  # Attempt to delete the test cluster (should be denied by Gatekeeper)
  run kubectl delete cluster test-cluster -n "${NAMESPACE}"

  # Cleanup (force delete with annotation)
  kubectl annotate cluster test-cluster -n "${NAMESPACE}" elastisys.io/ok-to-delete=true --overwrite || true
  kubectl delete cluster test-cluster -n "${NAMESPACE}" --ignore-not-found
  delete_namespace

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - error delete openstackcluster without annotation" {
  with_kubeconfig sc
  with_namespace opa-admin-test

  # Skip if CAPI OpenStackCluster CRD is not installed (optional component)
  if ! kubectl get crd openstackclusters.infrastructure.cluster.x-k8s.io &>/dev/null; then
    skip "Cluster API OpenStack provider not installed (openstackclusters CRD not found)"
  fi

  # Create test namespace and resource
  create_namespace
  kubectl apply -f - <<EOF
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: OpenStackCluster
metadata:
  name: test-openstack-cluster
  namespace: ${NAMESPACE}
spec:
  identityRef:
    name: test-openstack-credentials
    cloudName: openstack
EOF

  # Attempt to delete the test OpenStackCluster (should be denied by Gatekeeper)
  run kubectl delete openstackcluster test-openstack-cluster -n "${NAMESPACE}"

  # Cleanup (force delete with annotation)
  kubectl annotate openstackcluster test-openstack-cluster -n "${NAMESPACE}" elastisys.io/ok-to-delete=true --overwrite || true
  kubectl delete openstackcluster test-openstack-cluster -n "${NAMESPACE}" --ignore-not-found
  delete_namespace

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - error delete azurecluster without annotation" {
  with_kubeconfig sc
  with_namespace opa-admin-test

  # Skip if CAPI AzureCluster CRD is not installed (optional component)
  if ! kubectl get crd azureclusters.infrastructure.cluster.x-k8s.io &>/dev/null; then
    skip "Cluster API Azure provider not installed (azureclusters CRD not found)"
  fi

  # Create test namespace and resource
  create_namespace
  kubectl apply -f - <<EOF
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: AzureCluster
metadata:
  name: test-azure-cluster
  namespace: ${NAMESPACE}
spec:
  location: eastus
  subscriptionID: "00000000-0000-0000-0000-000000000000"
  resourceGroup: test-resource-group
EOF

  # Attempt to delete the test AzureCluster (should be denied by Gatekeeper)
  run kubectl delete azurecluster test-azure-cluster -n "${NAMESPACE}"

  # Cleanup (force delete with annotation)
  kubectl annotate azurecluster test-azure-cluster -n "${NAMESPACE}" elastisys.io/ok-to-delete=true --overwrite || true
  kubectl delete azurecluster test-azure-cluster -n "${NAMESPACE}" --ignore-not-found
  delete_namespace

  assert_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_line --regexp '.*deletion is not allowed.*'
  assert_failure
}

@test "opa gatekeeper policies - allow delete cluster with annotation" {
  with_kubeconfig sc
  with_namespace opa-admin-test

  # Skip if CAPI Cluster CRD is not installed (optional component)
  if ! kubectl get crd clusters.cluster.x-k8s.io &>/dev/null; then
    skip "Cluster API not installed (clusters.cluster.x-k8s.io CRD not found)"
  fi

  # Create test namespace and resource with the bypass annotation
  create_namespace
  kubectl apply -f - <<EOF
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: test-cluster
  namespace: ${NAMESPACE}
  annotations:
    elastisys.io/ok-to-delete: "true"
spec: {}
EOF

  # Attempt to delete should succeed with annotation
  run kubectl delete cluster test-cluster -n "${NAMESPACE}"

  # Cleanup
  delete_namespace

  refute_line --regexp '.*admission webhook "validation.gatekeeper.sh" denied the request.*'
  assert_success
}

# ============================================
# CRD creation policy test - Run on WC
# This test verifies that unauthorized users cannot create CRDs.
# ============================================

@test "opa gatekeeper policies - error unauthorized crd creation" {
  with_kubeconfig wc

  local -r test_user="opa-unlisted@example.com"
  local -r rbac_name="opa-user-crd-test"

  # Grant CRD create and get permissions so Gatekeeper (not RBAC) does the denial.
  # Note: 'get' is required because kubectl apply --dry-run=server checks if the resource exists.
  kubectl create clusterrole "${rbac_name}" \
    --verb=create,get \
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
  kubectl delete clusterrolebinding "${rbac_name}" --ignore-not-found
  kubectl delete clusterrole "${rbac_name}" --ignore-not-found

  assert_line --regexp '.*is not allowed to .* CRD.*'
  assert_failure
}
