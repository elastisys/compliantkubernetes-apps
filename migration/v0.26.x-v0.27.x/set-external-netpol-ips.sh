#!/bin/bash

set -e

yq4 -i '.networkPolicies.global.trivy.ips[0] = "0.0.0.0/0"' "${CK8S_CONFIG_PATH}"/common-config.yaml
yq4 -i '.networkPolicies.certManager.letsencrypt.ips[0] = "0.0.0.0/0"' "${CK8S_CONFIG_PATH}"/common-config.yaml
yq4 -i '.networkPolicies.alertmanager.alertReceivers.ips[0] = "0.0.0.0/0"' "${CK8S_CONFIG_PATH}"/common-config.yaml

yq4 -i '.networkPolicies.harbor.jobservice.ips[0] = "0.0.0.0/0"' "${CK8S_CONFIG_PATH}"/sc-config.yaml
yq4 -i '.networkPolicies.harbor.trivy.ips[0] = "0.0.0.0/0"' "${CK8S_CONFIG_PATH}"/sc-config.yaml
yq4 -i '.networkPolicies.monitoring.grafana.externalDashboardProvider.ips[0] = "0.0.0.0/0"' "${CK8S_CONFIG_PATH}"/sc-config.yaml
yq4 -i '.networkPolicies.opensearch.plugins.ips[0] = "0.0.0.0/0"' "${CK8S_CONFIG_PATH}"/sc-config.yaml
yq4 -i '.networkPolicies.dex.connectors.ips[0] = "0.0.0.0/0"' "${CK8S_CONFIG_PATH}"/sc-config.yaml
