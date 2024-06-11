#!/usr/bin/env bats

# bats file_tags=static,general,bin:conditional_set_me

setup_file() {
  load "../../../common/lib"
  load "../../../common/lib/env"
  load "../../../common/lib/gpg"

  env.setup
  gpg.setup

  common_setup

  export CK8S_FLAVOR=dev
  export CK8S_CLOUD_PROVIDER=baremetal
  ck8s init both
}

teardown_file() {
  env.teardown
  gpg.teardown
}

setup() {
  load "../../../common/lib"
  load "../../../common/lib/env"

  common_setup

  env.private
}

_apply_normalise_sc() {
  CK8S_AUTO_APPROVE=true ck8s validate sc 2>&1 | sed "s#${CK8S_CONFIG_PATH}#/tmp/ck8s-apps-config#g"
}

_apply_normalise_wc() {
  CK8S_AUTO_APPROVE=true ck8s validate wc 2>&1 | sed "s#${CK8S_CONFIG_PATH}#/tmp/ck8s-apps-config#g"
}

_assert_condition_and_warn() {
  assert_output --partial "Set-me condition matched for ${1}"
  assert_output --partial "WARN: ${1} is not set in config"
}

_refute_condition_and_warn() {
  refute_output --partial "Set-me condition matched for ${1}"
  refute_output --partial "WARN: ${1} is not set in config"
}

# bats test_tags=conditional_set_me_ingress_nginx
@test "conditional-set-me - singular conditions: ingressNginx" {

  yq_set common .ingressNginx.controller.service.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"type\"
  _assert_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"annotations\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"type\"
  _assert_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"annotations\"

  yq_set common .ingressNginx.controller.service.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"type\"
  _refute_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"annotations\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"type\"
  _refute_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"annotations\"
}

@test "conditional-set-me - singular conditions: letsencrypt" {

  yq_set common .issuers.letsencrypt.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"issuers\".\"letsencrypt\".\"prod\".\"email\"
  _assert_condition_and_warn .\"issuers\".\"letsencrypt\".\"staging\".\"email\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"issuers\".\"letsencrypt\".\"prod\".\"email\"
  _assert_condition_and_warn .\"issuers\".\"letsencrypt\".\"staging\".\"email\"

  yq_set common .issuers.letsencrypt.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"issuers\".\"letsencrypt\".\"prod\".\"email\"
  _refute_condition_and_warn .\"issuers\".\"letsencrypt\".\"staging\".\"email\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"issuers\".\"letsencrypt\".\"prod\".\"email\"
  _refute_condition_and_warn .\"issuers\".\"letsencrypt\".\"staging\".\"email\"
}

@test "conditional-set-me - singular conditions: opsgenie alerts" {

  yq_set common .alerts.opsGenieHeartbeat.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"alerts\".\"opsGenieHeartbeat\".\"name\"

  yq_set common .alerts.opsGenieHeartbeat.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"alerts\".\"opsGenieHeartbeat\".\"name\"
}

@test "conditional-set-me - singular conditions: slack alerts" {

  yq_set common .alerts.alertTo \"slack\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"alerts\".\"slack\".\"channel\"

  yq_set common .alerts.alertTo \"\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"alerts\".\"slack\".\"channel\"
}

# bats test_tags=conditional_set_me_netpol_singular
@test "conditional-set-me - singular conditions: network policies sc" {

  yq_set common .trivy.enabled 'true'
  yq_set common .networkPolicies.certManager.enabled 'true'
  yq_set common .networkPolicies.coredns.enabled 'true'
  yq_set sc .harbor.persistence.type \"swift\"
  yq_set sc .networkPolicies.opensearch.enabled 'true'
  yq_set sc .objectStorage.sync.secondaryUrl \"example.com\"
  yq_set sc .networkPolicies.ingressNginx.ingressOverride.enabled 'true'
  yq_set sc .networkPolicies.dex.enabled 'true'

  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"global\".\"trivy\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"certManager\".\"letsencrypt\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"coredns\".\"externalDns\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"coredns\".\"serviceIp\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"global\".\"objectStorageSwift\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"opensearch\".\"plugins\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"secondaryUrl\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"ingressNginx\".\"ingressOverride\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"dex\".\"connectors\".\"ips\"

  yq_set common .trivy.enabled 'false'
  yq_set common .networkPolicies.certManager.enabled 'false'
  yq_set common .networkPolicies.coredns.enabled 'false'
  yq_set sc .harbor.persistence.type \"s3\"
  yq_set sc .networkPolicies.opensearch.enabled 'false'
  yq_set sc .objectStorage.sync.secondaryUrl \"\"
  yq_set sc .networkPolicies.ingressNginx.ingressOverride.enabled 'false'
  yq_set sc .networkPolicies.dex.enabled 'false'

  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"global\".\"trivy\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"certManager\".\"letsencrypt\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"coredns\".\"externalDns\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"coredns\".\"serviceIp\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"global\".\"objectStorageSwift\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"opensearch\".\"plugins\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"secondaryUrl\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"ingressNginx\".\"ingressOverride\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"dex\".\"connectors\".\"ips\"

}

@test "conditional-set-me - singular conditions: network policies wc" {

  yq_set common .trivy.enabled 'true'
  yq_set common .networkPolicies.certManager.enabled 'true'
  yq_set common .networkPolicies.coredns.enabled 'true'
  yq_set wc .networkPolicies.ingressNginx.ingressOverride.enabled 'true'

  run _apply_normalise_wc
  _assert_condition_and_warn .\"networkPolicies\".\"global\".\"trivy\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"certManager\".\"letsencrypt\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"coredns\".\"externalDns\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"ingressNginx\".\"ingressOverride\".\"ips\"

  yq_set common .trivy.enabled 'false'
  yq_set common .networkPolicies.certManager.enabled 'false'
  yq_set common .networkPolicies.coredns.enabled 'false'
  yq_set wc .networkPolicies.ingressNginx.ingressOverride.enabled 'false'

  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"global\".\"trivy\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"certManager\".\"letsencrypt\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"coredns\".\"externalDns\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"ingressNginx\".\"ingressOverride\".\"ips\"
}

@test "conditional-set-me - multiple conditions: network policies kured" {

  yq_set common .kured.enabled 'true'
  yq_set common .kured.notification.slack.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"

  yq_set common .kured.enabled 'true'
  yq_set common .kured.notification.slack.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"

  yq_set common .kured.enabled 'false'
  yq_set common .kured.notification.slack.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"

  yq_set common .kured.enabled 'false'
  yq_set common .kured.notification.slack.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
}

@test "conditional-set-me - multiple conditions: network policies falco" {

  yq_set common .falco.enabled 'true'
  yq_set common .networkPolicies.falco.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"

  yq_set common .falco.enabled 'true'
  yq_set common .networkPolicies.falco.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"

  yq_set common .falco.enabled 'false'
  yq_set common .networkPolicies.falco.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"

  yq_set common .falco.enabled 'false'
  yq_set common .networkPolicies.falco.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_externaldns
@test "conditional-set-me - multiple conditions: network policies externalDns" {

  yq_set common .externalDns.enabled 'true'
  yq_set common .networkPolicies.externalDns.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"

  yq_set common .externalDns.enabled 'true'
  yq_set common .networkPolicies.externalDns.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"

  yq_set common .externalDns.enabled 'false'
  yq_set common .networkPolicies.externalDns.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"

  yq_set common .externalDns.enabled 'false'
  yq_set common .networkPolicies.externalDns.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
}

@test "conditional-set-me - multiple conditions: network policies harbor" {

  yq_set sc .harbor.enabled 'true'
  yq_set sc .networkPolicies.harbor.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"harbor\".\"registries\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"harbor\".\"jobservice\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"harbor\".\"trivy\".\"ips\"

  yq_set sc .harbor.enabled 'true'
  yq_set sc .networkPolicies.harbor.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"registries\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"jobservice\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"trivy\".\"ips\"

  yq_set sc .harbor.enabled 'false'
  yq_set sc .networkPolicies.harbor.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"registries\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"jobservice\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"trivy\".\"ips\"

  yq_set sc .harbor.enabled 'false'
  yq_set sc .networkPolicies.harbor.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"registries\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"jobservice\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"trivy\".\"ips\"
}

@test "conditional-set-me - multiple conditions: network policies monitoring" {

  yq_set sc .networkPolicies.monitoring.enabled 'true'
  yq_set sc .networkPolicies.monitoring.grafana.externalDataSources.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ports\"

  yq_set sc .networkPolicies.monitoring.enabled 'true'
  yq_set sc .networkPolicies.monitoring.grafana.externalDataSources.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ports\"

  yq_set sc .networkPolicies.monitoring.enabled 'false'
  yq_set sc .networkPolicies.monitoring.grafana.externalDataSources.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ports\"

  yq_set sc .networkPolicies.monitoring.enabled 'false'
  yq_set sc .networkPolicies.monitoring.grafana.externalDataSources.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ports\"
}

@test "conditional-set-me - multiple conditions: network policies rclone s3" {

  yq_set sc .objectStorage.sync.enabled 'true'
  yq_set sc .objectStorage.type \"s3\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorage\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'true'
  yq_set sc .objectStorage.type \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorage\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'false'
  yq_set sc .objectStorage.type \"s3\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorage\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'false'
  yq_set sc .objectStorage.type \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorage\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_rclone_swift
@test "conditional-set-me - multiple conditions: network policies rclone swift" {

  yq_set sc .objectStorage.sync.enabled 'true'
  yq_set sc .harbor.persistence.type \"swift\"
  yq_set sc .thanos.objectStorage.type \"swift\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'true'
  yq_set sc .harbor.persistence.type \"swift\"
  yq_set sc .thanos.objectStorage.type \"s3\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'true'
  yq_set sc .harbor.persistence.type \"s3\"
  yq_set sc .thanos.objectStorage.type \"swift\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'true'
  yq_set sc .harbor.persistence.type \"s3\"
  yq_set sc .thanos.objectStorage.type \"s3\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'false'
  yq_set sc .harbor.persistence.type \"swift\"
  yq_set sc .thanos.objectStorage.type \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'false'
  yq_set sc .harbor.persistence.type \"swift\"
  yq_set sc .thanos.objectStorage.type \"s3\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'false'
  yq_set sc .harbor.persistence.type \"s3\"
  yq_set sc .thanos.objectStorage.type \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq_set sc .objectStorage.sync.enabled 'false'
  yq_set sc .harbor.persistence.type \"s3\"
  yq_set sc .thanos.objectStorage.type \"s3\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"
}
