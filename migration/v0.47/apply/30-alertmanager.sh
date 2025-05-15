#!/usr/bin/env bash

set -euo pipefail

export CK8S_STACK="migration/user-alertmanager"
ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

source "${ROOT}/scripts/migration/lib.sh"

# Load workload cluster config (wc)
config_load wc

log_info "Applying kube-prometheus-stack chart in WC..."
helmfile_apply wc app=prometheus

#Delete the user-alertmanager Helm release if it exists
log_info "Checking for 'user-alertmanager' Helm release in workload cluster..."

if helmfile_list wc name=user-alertmanager | grep -q 'user-alertmanager'; then
  log_info "Deleting 'user-alertmanager' Helm release..."
  helmfile_destroy wc name=user-alertmanager
  log_info "user-alertmanager Helm release deleted successfully."
else
  log_warn "user-alertmanager Helm release not found. Skipping deletion."
fi

#upgrading user-rbac to add roles for alertmanager
log_info "Applying dev-rbac chart in WC..."
helmfile_apply wc app=dev-rbac

#Extract alertmanager config from old secret
log_info "Extracting alertmanager.yaml from old secret..."

kubectl_do wc get secret alertmanager-alertmanager -n alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d >alertmanager.yaml

if [[ ! -s alertmanager.yaml ]]; then
  log_fatal "Extracted alertmanager.yaml is empty or missing."
fi

# Patch the new kube-prometheus-stack secret with the old config
log_info "Patching new kube-prometheus-stack Alertmanager secret..."

kubectl_do wc patch secret alertmanager-kube-prometheus-stack-alertmanager -n alertmanager -p "{\"data\":{\"alertmanager.yaml\":\"$(base64 -w 0 <alertmanager.yaml)\"}}"

patch_exit=$?

if [[ $patch_exit -eq 0 ]]; then
  log_info "Secret patched successfully."

  # Delete the old secret
  log_info "Deleting old alertmanager-alertmanager secret..."
  kubectl_delete wc secret alertmanager-alertmanager alertmanager
  log_info "Old secret deleted."

  # Cleanup
  rm alertmanager.yaml
else
  log_fatal "Failed to patch the kube-prometheus-stack secret. Skipping deletion of old secret."
fi
