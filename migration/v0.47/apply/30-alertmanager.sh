#!/usr/bin/env bash

ROOT="$(readlink -f "$(dirname "${0}")/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

run() {
  case "${1:-}" in
  execute)
    if [[ "${CK8S_CLUSTER}" =~ ^(wc|both)$ ]]; then
      log_info "operation on workload cluster"
      config_load wc

      # Delete the user-alertmanager Helm release if it exists
      log_info "Checking for 'user-alertmanager' Helm release in workload cluster..."

      if helm_installed wc alertmanager user-alertmanager; then
        log_info "Deleting 'user-alertmanager' Helm release..."
        helm_uninstall wc alertmanager user-alertmanager
        log_info "user-alertmanager Helm release deleted successfully."
      else
        log_warn "'user-alertmanager' Helm release not found. Skipping deletion."
      fi

      log_info "Applying kube-prometheus-stack chart in WC..."
      helmfile_apply wc app=prometheus

      log_info "Applying dev-rbac chart in WC..."
      helmfile_apply wc app=dev-rbac

      TMP_FILE="/tmp/alertmanager.yaml"

      log_info "Extracting alertmanager.yaml from old secret..."

      kubectl_do wc get secret alertmanager-alertmanager -n alertmanager \
        -o jsonpath='{.data.alertmanager\.yaml}' 2>/dev/null | base64 -d >"$TMP_FILE" || true

      if [[ ! -s "$TMP_FILE"  ]]; then
        log_warn "alertmanager.yaml is empty or missing — likely already migrated."
      fi

      # Patch the new secret with old config, only if alertmanager.yaml exists and is non-empty
      if [[ -s "$TMP_FILE" ]]; then
        log_info "Patching new kube-prometheus-stack Alertmanager secret..."

        kubectl_do wc patch secret alertmanager-kube-prometheus-stack-alertmanager -n alertmanager \
          -p "{\"data\":{\"alertmanager.yaml\":\"$(base64 -w 0 < "$TMP_FILE")\"}}"

        patch_exit=$?

        if [[ $patch_exit -eq 0 ]]; then
          log_info "Secret patched successfully."

          # Delete the old secret
          log_info "Deleting old alertmanager-alertmanager secret..."
          kubectl_delete wc secret alertmanager alertmanager-alertmanager
          log_info "Old secret deleted."

          # Cleanup
           rm -f "$TMP_FILE"
        else
          log_error "Failed to patch the kube-prometheus-stack secret. Skipping deletion of old secret."
        fi
      else
        log_warn "Skipping patch: alertmanager.yaml is missing or empty — likely already migrated."
      fi
    fi
    ;;
  rollback)
    log_warn "rollback not implemented"
    ;;
  *)
    log_fatal "usage: \"${0}\" <execute|rollback>"
    ;;
  esac
}

run "${@}"
