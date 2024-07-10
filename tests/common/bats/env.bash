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
  if [[ -z "${1:-}" ]] || [[ -z "${2:-}" ]] || [[ -z "${3:-}" ]]; then
    log_fatal "usage: env.init [provider] [installer] [flavor]"
  fi

  export CK8S_CLOUD_PROVIDER="${1}"
  export CK8S_K8S_INSTALLER="${2}"
  export CK8S_FLAVOR="${3}"

  ck8s init both

  yq.set 'common' '.global.baseDomain' '"ck8s.example.com"'
  yq.set 'common' '.global.opsDomain' '"ops.ck8s.example.com"'

  if ! [[ "$*" =~ --skip-object-storage ]]; then
    yq.set 'common' '.objectStorage.type' '"s3"'
    yq.set 'common' '.objectStorage.s3.region' '"example-region"'
    yq.set 'common' '.objectStorage.s3.regionEndpoint' '"https://example-region-endpoint"'
    yq.set 'common' '.objectStorage.s3.forcePathStyle' 'true'
    yq.set 'secrets' '["objectStorage"]["s3"]["accessKey"]' '"example-access-key"'
    yq.set 'secrets' '["objectStorage"]["s3"]["secretKey"]' '"example-secret-key"'

    if [[ "${CK8S_CLOUD_PROVIDER}" =~ (citycloud|elastx) ]]; then
      yq.set 'sc' '.objectStorage.swift.authVersion' '0'
      yq.set 'sc' '.objectStorage.swift.authUrl' '"https://auth.url.example"'
      yq.set 'sc' '.objectStorage.swift.region' '"example-region"'
      yq.set 'sc' '.objectStorage.swift.projectDomainId' '"example-project-domain-id"'
      yq.set 'sc' '.objectStorage.swift.projectId' '"example-project-id"'
      yq.set 'sc' '.objectStorage.swift.domainId' '"example-domain-id"'
      yq.set 'secrets' '["objectStorage"]["swift"]["username"]' '"example-username"'
      yq.set 'secrets' '["objectStorage"]["swift"]["password"]' '"example-password"'
    fi
  fi

  yq.set 'common' '.clusterAdmin.users' '["admin@example.com"]'

  if ! [[ "$*" =~ --skip-issuers ]]; then
    yq.set 'common' '.global.issuer' '"letsencrypt-staging"'
    yq.set 'common' '.issuers.letsencrypt.prod.email' '"admin@.example.com"'
    yq.set 'common' '.issuers.letsencrypt.staging.email' '"admin@.example.com"'
  fi

  yq.set 'sc' '.grafana.ops.oidc.allowedDomains' '["example.com"]'
  yq.set 'sc' '.grafana.user.oidc.allowedDomains' '["example.com"]'

  yq.set 'sc' '.harbor.oidc.adminGroupName' '"admin"'

  yq.set 'sc' '.opensearch.extraRoleMappings' '[]'

  if ! [[ "$*" =~ --skip-network-policies ]]; then
    yq.set 'common' '.networkPolicies.global.objectStorage.ips' '["0.0.0.0/0"]'
    yq.set 'common' '.networkPolicies.global.objectStorage.ports' '[443]'

    if [[ "${CK8S_CLOUD_PROVIDER}" =~ (citycloud|elastx) ]]; then
      yq.set 'sc' '.networkPolicies.global.objectStorageSwift.ips' '["0.0.0.0/0"]'
    fi

    yq.set 'common' '.networkPolicies.global.scIngress.ips' '["0.0.0.0/0"]'
    yq.set 'common' '.networkPolicies.global.wcIngress.ips' '["0.0.0.0/0"]'

    yq.set 'sc' '.networkPolicies.global.scApiserver.ips' '["0.0.0.0/0"]'
    yq.set 'sc' '.networkPolicies.global.scNodes.ips' '["0.0.0.0/0"]'

    yq.set 'wc' '.networkPolicies.global.wcApiserver.ips' '["0.0.0.0/0"]'
    yq.set 'wc' '.networkPolicies.global.wcNodes.ips' '["0.0.0.0/0"]'

    yq.set 'common' '.networkPolicies.global.trivy.ips' '["0.0.0.0/0"]'

    yq.set 'common' '.networkPolicies.alertmanager.alertReceivers.ips' '["0.0.0.0/0"]'

    yq.set 'common' '.networkPolicies.certManager.letsencrypt.ips' '["0.0.0.0/0"]'

    yq.set 'common' '.networkPolicies.coredns.externalDns.ips' '["0.0.0.0/0"]'

    yq.set 'sc' '.networkPolicies.dex.connectors.ips' '["0.0.0.0/0"]'

    yq.set 'common' '.networkPolicies.falco.plugins.ips' '["0.0.0.0/0"]'

    yq.set 'sc' '.networkPolicies.harbor.jobservice.ips' '["0.0.0.0/0"]'
    yq.set 'sc' '.networkPolicies.harbor.registries.ips' '["0.0.0.0/0"]'
    yq.set 'sc' '.networkPolicies.harbor.trivy.ips' '["0.0.0.0/0"]'

    if [[ "${CK8S_CLOUD_PROVIDER}" =~ (citycloud|elastx|openstack|safespring) ]]; then
      yq.set 'common' '.networkPolicies.kubeSystem.openstack.ips' '["0.0.0.0/0"]'
    fi

    yq.set 'sc' '.networkPolicies.monitoring.grafana.externalDashboardProvider.ips' '["0.0.0.0/0"]'
    yq.set 'sc' '.networkPolicies.opensearch.plugins.ips' '["0.0.0.0/0"]'
  fi

  if [[ "${CK8S_FLAVOR}" = "prod" ]]; then
    yq.set 'sc' '.alerts.opsGenieHeartbeat.name' '"example-heartbeat-name"'
  fi

  yq.set 'wc' '.opa.imageRegistry.URL' '["harbor.ck8s.example.com"]'

  yq.set 'wc' '.user.adminUsers' '["user@example.com"]'
  yq.set 'wc' '.user.adminGroups' '["group@example.com"]'

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
