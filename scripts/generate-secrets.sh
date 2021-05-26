#!/bin/bash

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

# https://unix.stackexchange.com/questions/307994/compute-bcrypt-hash-from-command-line

ES_ADM_PASS=$(pwgen -cns 20 1)
ES_ADM_PASS_HASH=$(htpasswd -bnBC 10 "" "${ES_ADM_PASS}" | tr -d ':\n')

ES_CONF_PASS=$(pwgen -cns 20 1)
ES_CONF_PASS_HASH=$(htpasswd -bnBC 10 "" "${ES_CONF_PASS}" | tr -d ':\n')

ES_KIBANA_PASS=$(pwgen -cns 20 1)
ES_KIBANA_PASS_HASH=$(htpasswd -bnBC 10 "" "${ES_KIBANA_PASS}" | tr -d ':\n')

DEX_STATIC_PASS=$(pwgen -cns 20 1)
# shellcheck disable=SC2016 # We need single quotes for this one
DEX_STATIC_PASS_HASH=$(htpasswd -bnBC 10 "" "${DEX_STATIC_PASS}" | tr -d ':\n' | sed 's/$2y/$2a/')

PROMETHEUS_WC_REMOTE_WRITE_PASS=$(pwgen -cns 20 1)

sops -d "${CK8S_CONFIG_PATH}/secrets.yaml" | \
  yq w - 'grafana.password' "$(pwgen -cns 20 1)" | \
  yq w - 'grafana.clientSecret' "$(pwgen -cns 20 1)" | \
  yq w - 'grafana.opsClientSecret' "$(pwgen -cns 20 1)" | \
  yq w - 'harbor.password' "$(pwgen -cns 20 1)" | \
  yq w - 'harbor.databasePassword' "$(pwgen -cns 20 1)" | \
  yq w - 'harbor.clientSecret' "$(pwgen -cns 20 1)" | \
  yq w - 'harbor.xsrf' "$(pwgen -cns 20 1)" | \
  yq w - 'harbor.coreSecret' "$(pwgen -cns 20 1)" | \
  yq w - 'harbor.jobserviceSecret' "$(pwgen -cns 20 1)" | \
  yq w - 'harbor.registrySecret' "$(pwgen -cns 20 1)" | \
  yq w - 'influxDB.users.adminPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'influxDB.users.wcWriterPassword' "${PROMETHEUS_WC_REMOTE_WRITE_PASS}" | \
  yq w - 'influxDB.users.scWriterPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'elasticsearch.adminPassword' "${ES_ADM_PASS}" | \
  yq w - 'elasticsearch.adminHash' "${ES_ADM_PASS_HASH}" | \
  yq w - 'elasticsearch.clientSecret' "$(pwgen -cns 20 1)" | \
  yq w - 'elasticsearch.configurerPassword' "${ES_CONF_PASS}" | \
  yq w - 'elasticsearch.configurerHash' "${ES_CONF_PASS_HASH}" | \
  yq w - 'elasticsearch.kibanaPassword' "${ES_KIBANA_PASS}" | \
  yq w - 'elasticsearch.kibanaHash' "${ES_KIBANA_PASS_HASH}" | \
  yq w - 'elasticsearch.fluentdPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'elasticsearch.curatorPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'elasticsearch.snapshotterPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'elasticsearch.metricsExporterPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'elasticsearch.kibanaCookieEncKey' "$(pwgen -cns 32 1)" | \
  yq w - 'kubeapiMetricsPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'dex.staticPasswordNotHashed' "${DEX_STATIC_PASS}" | \
  yq w - 'dex.staticPassword' "${DEX_STATIC_PASS_HASH}" | \
  yq w - 'dex.kubeloginClientSecret' "$(pwgen -cns 20 1)" | \
  yq w - 'user.grafanaPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'user.alertmanagerPassword' "$(pwgen -cns 20 1)" | \
  yq w - 'prometheus.remoteWrite.password' "${PROMETHEUS_WC_REMOTE_WRITE_PASS}" | \
  sops --config "${CK8S_CONFIG_PATH}/.sops.yaml" --input-type=yaml --output-type=yaml -e /dev/stdin > "${CK8S_CONFIG_PATH}/secrets_tmp.yaml"

echo ""
echo "The script has created a new file \"${CK8S_CONFIG_PATH}/secrets_tmp.yaml\" with updated secrets"
echo "Please review the file and run \"mv ${CK8S_CONFIG_PATH}/secrets_tmp.yaml ${CK8S_CONFIG_PATH}/secrets.yaml\" to apply them"
