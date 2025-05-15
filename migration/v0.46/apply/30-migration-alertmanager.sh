#!/usr/bin/env bash

set -euo pipefail
export CK8S_STACK="migration/user-alertmanager-secret"
ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

source "${ROOT}/scripts/migration/lib.sh"

# Ensure wc config is loaded
config_load wc

# Extract alertmanager config from old secret
kubectl_do wc get secret alertmanager-alertmanager -n alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d > alertmanager.yaml

if [[ ! -s alertmanager.yaml ]]; then
  log_fatal "Extracted alertmanager.yaml is empty or missing"
fi

# Patch the new secret using wc kubeconfig
kubectl_do wc patch secret alertmanager-kube-prometheus-stack-alertmanager \
  -n alertmanager \
  -p "{\"data\":{\"alertmanager.yaml\":\"$(base64 -w 0 < alertmanager.yaml)\"}}"

patch_exit=$?

if [[ $patch_exit -eq 0 ]]; then
  log_info "Secret patched successfully."

  log_info "Deleting old alertmanager-alertmanager secret..."
  kubectl_delete wc secret alertmanager-alertmanager alertmanager

  log_info "Old secret deleted."
  rm alertmanager.yaml
else
  log_fatal "Failed to patch the kube-prometheus-stack secret. Skipping deletion of old secret."
fi