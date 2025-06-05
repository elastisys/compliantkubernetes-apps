#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${CK8S_CONFIG_PATH:?Environment variable CK8S_CONFIG_PATH must be set}"
COMMON_CONFIG="${CONFIG_PATH}/defaults/common-config.yaml"
WC_CONFIG="${CONFIG_PATH}/defaults/wc-config.yaml"

migrate_common_config() {
  if [[ "$(yq e '.user.alertmanager.enabled // "null"' "$COMMON_CONFIG")" == "null" ]]; then
    echo "No .user.alertmanager.enabled found in common-config.yaml, skipping."
    return
  fi

  echo "Migrating alertmanager.enabled to prometheus.devAlertmanager.enabled in common-config.yaml..."

  yq e '
    .prometheus.devAlertmanager.enabled = .user.alertmanager.enabled |
    del(.user)
  ' -i "$COMMON_CONFIG"

  echo "Migration complete for common-config.yaml"
}

migrate_wc_config() {
  if [[ "$(yq e '.user.alertmanager.enabled // "null"' "$WC_CONFIG")" == "null" ]]; then
    echo "No .user.alertmanager.enabled found in wc-config.yaml, skipping."
    return
  fi

  echo "Migrating alertmanager to prometheus.devAlertmanager in wc-config.yaml..."

  yq e '
    .prometheus.devAlertmanager.enabled = .user.alertmanager.enabled |
    .prometheus.devAlertmanager.namespace = "alertmanager" |
    .prometheus.devAlertmanager.ingressEnabled = false |
    .prometheus.devAlertmanager.username = "alertmanager" |
    .prometheus.alertmanagerSpec.groupBy = ["alertname"] |
    del(.user.alertmanager)
  ' -i "$WC_CONFIG"

  echo "Migration complete for wc-config.yaml"
}

# Run both
migrate_common_config
migrate_wc_config
