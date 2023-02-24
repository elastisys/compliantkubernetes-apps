#!/bin/bash

set -euo pipefail

SCRIPTS_PATH="$(dirname "$(readlink -f "$0")")"
# shellcheck source=bin/common.bash
source "${SCRIPTS_PATH}/../bin/common.bash"

config_load wc --skip-validation

: "${config[config_file_wc]:?Missing config}"
: "${secrets[secrets_file]:?Missing secrets}"

# Arg for Helmfile to be interactive so that one can decide on which releases
# to update if changes are found.
# USE: --interactive, default is not interactive.
INTERACTIVE=${1:-""}

# Add example resources.
# We use `create` here instead of `apply` to avoid overwriting any changes the
# user may have done.
if [ "$(kubectl get configmap fluentd-extra-config -n fluentd)" ] ; then
  echo "fluentd-extra-config ConfigMap already in place. Ignoring."
else
  echo "Creating fluentd-extra-config ConfigMap"
  kubectl create -f "${SCRIPTS_PATH}/../manifests/examples/fluentd/fluentd-extra-config.yaml"
fi

if [ "$(kubectl get configmap fluentd-extra-plugins -n fluentd)" ] ; then
  echo "fluentd-extra-plugins ConfigMap already in place. Ignoring."
else
  echo "Creating fluentd-extra-plugins ConfigMap"
  kubectl create -f "${SCRIPTS_PATH}/../manifests/examples/fluentd/fluentd-extra-plugins.yaml"
fi

if [ "$(kubectl get clusterrolebinding extra-user-view)" ] ; then
  echo "extra-user-view ClusterRoleBinding already in place. Ignoring."
else
  echo "Creating extra-user-view ClusterRoleBinding"
  kubectl create -f "${SCRIPTS_PATH}/../manifests/user-rbac/clusterrolebindings/extra-user-view.yaml"
fi

user_namespaces=$(yq4 '.user.namespaces[]' "${config['config_file_wc']}")

for namespace in ${user_namespaces}; do
    if [ "$(kubectl get rolebinding -n "${namespace}" extra-workload-admins)" ] ; then
        echo "extra-workload-admins RoleBinding already exists in ${namespace} namespace. Ignoring."
    else
        echo "Creating extra-workload-admins RoleBinding in ${namespace} namespace"
        kubectl create rolebinding extra-workload-admins -n "${namespace}" --clusterrole=admin
    fi
done

echo "Installing helm charts" >&2
cd "${SCRIPTS_PATH}/../helmfile"
declare -a helmfile_opt_flags
[[ -n "$INTERACTIVE" ]] && helmfile_opt_flags+=("$INTERACTIVE")

if [ ${#} -eq 1 ] && [ "$1" = "sync" ]; then
    helmfile -f . -e workload_cluster sync
else
    helmfile -f . -e workload_cluster apply --suppress-diff
fi

echo "Deploy wc completed!" >&2
