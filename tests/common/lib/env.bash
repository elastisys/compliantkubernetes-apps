#!/usr/bin/env bash

# Helpers to manage environments for tests

# Setup environment
env.setup() {
  CK8S_CONFIG_PATH="$(mktemp --directory)"

  export CK8S_CONFIG_PATH

  export CK8S_ENVIRONMENT_NAME="apps-tests"
}

# Initialise environment
env.init() {
  if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]]; then
    log_fatal "usage: env.init [flavour] [cloud] [k8s-installer]"
  fi

  export CK8S_FLAVOR="${1}"
  export CK8S_CLOUD_PROVIDER="${2}"
  export CK8S_K8S_INSTALLER="${3}"

  ck8s init both

  yq_set 'common' '.global.baseDomain' '"ck8s.example.com"'
  yq_set 'common' '.global.opsDomain' '"ops.ck8s.example.com"'

  if ! [[ "$*" =~ --skip-object-storage ]]; then
    yq_set 'common' '.objectStorage.type' '"s3"'
    yq_set 'common' '.objectStorage.s3.region' '"example-region"'
    yq_set 'common' '.objectStorage.s3.regionEndpoint' '"https://example-region-endpoint"'
    yq_set 'common' '.objectStorage.s3.forcePathStyle' 'true'
    yq_set 'secrets' '["objectStorage"]["s3"]["accessKey"]' '"example-access-key"'
    yq_set 'secrets' '["objectStorage"]["s3"]["secretKey"]' '"example-secret-key"'

    if [[ "${CK8S_CLOUD_PROVIDER}" = "citycloud" ]]; then
      yq_set 'sc' '.objectStorage.swift.authVersion' '0'
      yq_set 'sc' '.objectStorage.swift.authUrl' '"https://auth.url.example"'
      yq_set 'sc' '.objectStorage.swift.region' '"example-region"'
      yq_set 'sc' '.objectStorage.swift.projectDomainId' '"example-project-domain-id"'
      yq_set 'sc' '.objectStorage.swift.projectId' '"example-project-id"'
      yq_set 'sc' '.objectStorage.swift.domainId' '"example-domain-id"'
      yq_set 'secrets' '["objectStorage"]["swift"]["username"]' '"example-username"'
      yq_set 'secrets' '["objectStorage"]["swift"]["password"]' '"example-password"'
    fi

    if [[ "$(yq_dig sc .harbor.persistence.type)" == "swift" || "$(yq_dig sc .thanos.objectStorage.type)" == "swift" ]]; then
      yq_set 'sc' '.networkPolicies.global.objectStorageSwift.ips' '["0.0.0.0/0"]'
    fi
  fi

  yq_set 'common' '.clusterAdmin.users' '["admin@example.com"]'

  yq_set 'common' '.global.issuer' '"letsencrypt-staging"'
  yq_set 'common' '.issuers.letsencrypt.prod.email' '"admin@.example.com"'
  yq_set 'common' '.issuers.letsencrypt.staging.email' '"admin@.example.com"'

  yq_set 'sc' '.grafana.ops.oidc.allowedDomains' '["example.com"]'
  yq_set 'sc' '.grafana.user.oidc.allowedDomains' '["example.com"]'

  yq_set 'sc' '.harbor.oidc.adminGroupName' '"admin"'

  yq_set 'sc' '.opensearch.extraRoleMappings' '[]'

  yq_set 'sc' '.alerts.opsGenieHeartbeat.name' '"example"'

  if ! [[ "$*" =~ --skip-network-policies ]]; then
    yq_set 'common' '.networkPolicies.global.objectStorage.ips' '["0.0.0.0/0"]'
    yq_set 'common' '.networkPolicies.global.objectStorage.ports' '[443]'

    yq_set 'common' '.networkPolicies.global.scIngress.ips' '["0.0.0.0/0"]'
    yq_set 'common' '.networkPolicies.global.wcIngress.ips' '["0.0.0.0/0"]'

    yq_set 'sc' '.networkPolicies.global.scApiserver.ips' '["0.0.0.0/0"]'
    yq_set 'sc' '.networkPolicies.global.scNodes.ips' '["0.0.0.0/0"]'

    yq_set 'wc' '.networkPolicies.global.wcApiserver.ips' '["0.0.0.0/0"]'
    yq_set 'wc' '.networkPolicies.global.wcNodes.ips' '["0.0.0.0/0"]'

    yq_set 'common' '.networkPolicies.global.trivy.ips' '["0.0.0.0/0"]'

    yq_set 'common' '.networkPolicies.alertmanager.alertReceivers.ips' '["0.0.0.0/0"]'

    yq_set 'common' '.networkPolicies.certManager.letsencrypt.ips' '["0.0.0.0/0"]'

    yq_set 'common' '.networkPolicies.coredns.externalDns.ips' '["0.0.0.0/0"]'

    yq_set 'sc' '.networkPolicies.dex.connectors.ips' '["0.0.0.0/0"]'

    yq_set 'common' '.networkPolicies.falco.plugins.ips' '["0.0.0.0/0"]'

    yq_set 'sc' '.networkPolicies.harbor.jobservice.ips' '["0.0.0.0/0"]'
    yq_set 'sc' '.networkPolicies.harbor.registries.ips' '["0.0.0.0/0"]'
    yq_set 'sc' '.networkPolicies.harbor.trivy.ips' '["0.0.0.0/0"]'

    yq_set 'sc' '.networkPolicies.monitoring.grafana.externalDashboardProvider.ips' '["0.0.0.0/0"]'
    yq_set 'sc' '.networkPolicies.opensearch.plugins.ips' '["0.0.0.0/0"]'

    if [[ "$(yq_dig sc .networkPolicies.kubeSystem.openstack.enabled)" == "true" ]]; then
      yq_set 'common' '.networkPolicies.kubeSystem.openstack.ips' '["0.0.0.0/0"]'
    fi
  fi

  yq_set 'wc' '.opa.imageRegistry.URL' '["harbor.ck8s.example.com"]'

  yq_set 'wc' '.user.adminUsers' '["user@example.com"]'
  yq_set 'wc' '.user.adminGroups' '["group@example.com"]'

  mkdir -p "${CK8S_CONFIG_PATH}/.state"
  touch "${CK8S_CONFIG_PATH}/.state/kube_config_sc.yaml"
  touch "${CK8S_CONFIG_PATH}/.state/kube_config_wc.yaml"
}

# Teardown environment
env.teardown() {
  rm -rf "${CK8S_CONFIG_PATH}"
}

# Create a private copy of the current config path
env.private() {
  if [[ -z "${CK8S_CONFIG_PATH:-}" ]]; then
    fail "CK8S_CONFIG_PATH is unset!"
  fi

  local target
  target="$(mktemp --directory)"

  cp -Tr "${CK8S_CONFIG_PATH}" "${target}"

  export CK8S_CONFIG_PATH="${target}"
}
