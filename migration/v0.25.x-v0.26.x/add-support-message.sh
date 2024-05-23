#!/usr/bin/env bash

# Requires yq4

set -euo pipefail

: "${CK8S_CONFIG_PATH:?Missing CK8S_CONFIG_PATH}"

sc_config="${CK8S_CONFIG_PATH}/sc-config.yaml"
sc_template="../template/common/sc-config.yaml"

if [ -f "${CK8S_CONFIG_PATH}"/"${sc_template}" ]; then
  GRAFANA_VALUE=$(yq4 '.welcomingDashboard.extraTextGrafana' "${CK8S_CONFIG_PATH}"/"${sc_template}")
  export GRAFANA_VALUE
  yq4 -i '.welcomingDashboard.extraTextGrafana = strenv(GRAFANA_VALUE) | .welcomingDashboard.extraTextGrafana style="double"' "${sc_config}"
  OPENSEARCH_VALUE=$(yq4 '.welcomingDashboard.extraTextOpensearch' "${CK8S_CONFIG_PATH}"/"${sc_template}")
  export OPENSEARCH_VALUE
  yq4 -i '.welcomingDashboard.extraTextOpensearch = strenv(OPENSEARCH_VALUE) | .welcomingDashboard.extraTextOpensearch style="double"' "${sc_config}"
# if the env has prod/dev folders
elif [ -f "${CK8S_CONFIG_PATH}"/../"${sc_template}" ]; then
  GRAFANA_VALUE=$(yq4 '.welcomingDashboard.extraTextGrafana' "${CK8S_CONFIG_PATH}"/../"${sc_template}")
  export GRAFANA_VALUE
  yq4 -i '.welcomingDashboard.extraTextGrafana = strenv(GRAFANA_VALUE) | .welcomingDashboard.extraTextGrafana style="double"' "${sc_config}"
  OPENSEARCH_VALUE=$(yq4 '.welcomingDashboard.extraTextOpensearch' "${CK8S_CONFIG_PATH}"/../"${sc_template}")
  export OPENSEARCH_VALUE
  yq4 -i '.welcomingDashboard.extraTextOpensearch = strenv(OPENSEARCH_VALUE) | .welcomingDashboard.extraTextOpensearch style="double"' "${sc_config}"
else
  printf "%s/%s or %s/../%s: file not found" "${CK8S_CONFIG_PATH}" "${sc_template}" "${CK8S_CONFIG_PATH}" "${sc_template}"
fi
