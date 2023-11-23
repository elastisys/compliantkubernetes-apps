#!/bin/bash

set -euo pipefail

SCRIPTS_PATH="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${SCRIPTS_PATH}/../bin/common.bash"

config_load wc --skip-validation

: "${config[config_file_wc]:?Missing config}"
: "${secrets[secrets_file]:?Missing secrets}"

echo "Installing admin namespaces" >&2
cd "${SCRIPTS_PATH}/../helmfile.d"

if [ ${#} -eq 1 ] && [ "$1" = "sync" ]; then
    helmfile -f . -e workload_cluster -l app=admin-namespaces sync "$2"
else
    helmfile -f . -e workload_cluster -l app=admin-namespaces apply "$2" --suppress-diff
fi

cd "${SCRIPTS_PATH}"

# Add example resources.
# We use `create` here instead of `apply` to avoid overwriting any changes the
# user may have done.
if ! kubectl get ns fluentd > /dev/null; then
  echo "fluentd namespace missing, skipping installing fluentd example resources."
else
  if kubectl get configmap fluentd-extra-config -n fluentd > /dev/null; then
    echo "fluentd-extra-config ConfigMap already in place. Ignoring."
  else
    echo "Creating fluentd-extra-config ConfigMap"
    kubectl create -f "${SCRIPTS_PATH}/../manifests/examples/fluentd/fluentd-extra-config.yaml"
  fi

  if kubectl get configmap fluentd-extra-plugins -n fluentd > /dev/null ; then
    echo "fluentd-extra-plugins ConfigMap already in place. Ignoring."
  else
    echo "Creating fluentd-extra-plugins ConfigMap"
    kubectl create -f "${SCRIPTS_PATH}/../manifests/examples/fluentd/fluentd-extra-plugins.yaml"
  fi
fi

if kubectl get clusterrolebinding extra-user-view > /dev/null; then
  echo "extra-user-view ClusterRoleBinding already in place. Ignoring."
else
  echo "Creating extra-user-view ClusterRoleBinding"
  kubectl create -f "${SCRIPTS_PATH}/../manifests/user-rbac/clusterrolebindings/extra-user-view.yaml"
fi

echo "Installing helm charts" >&2
cd "${SCRIPTS_PATH}/../helmfile.d"

if [ ${#} -eq 1 ] && [ "$1" = "sync" ]; then
    helmfile -f . -e workload_cluster sync "$2"
else
    helmfile -f . -e workload_cluster apply "$2" --suppress-diff
fi

echo "Deploy wc completed!" >&2
