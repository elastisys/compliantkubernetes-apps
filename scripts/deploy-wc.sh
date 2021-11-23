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

echo "Creating OpenSearch and Fluentd secrets" >&2
opensearch_password=$(sops_exec_file "${secrets[secrets_file]}" 'yq r -e {} opensearch.fluentdPassword')

kubectl -n kube-system create secret generic opensearch \
    --from-literal=password="${opensearch_password}" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n fluentd create secret generic opensearch \
    --from-literal=password="${opensearch_password}" --dry-run=client -o yaml | kubectl apply -f -

# Add example resources.
# We use `create` here instead of `apply` to avoid overwriting any changes the
# user may have done.
kubectl create -f "${SCRIPTS_PATH}/../manifests/examples/fluentd/fluentd-extra-config.yaml" \
    2>/dev/null || echo "fluentd-extra-config configmap already in place. Ignoring."
kubectl create -f "${SCRIPTS_PATH}/../manifests/examples/fluentd/fluentd-extra-plugins.yaml" \
    2>/dev/null || echo "fluentd-extra-plugins configmap already in place. Ignoring." >&2

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
