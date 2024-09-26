#!/usr/bin/env bats

# bats file_tags=static,general,bin:conditional_set_me

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init baremetal kubespray dev --skip-issuers --skip-network-policies
}

teardown_file() {
  env.teardown
  gpg.teardown
}

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "yq.bash"
  load_assert

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

  yq.set common .ingressNginx.controller.service.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"type\"
  _assert_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"annotations\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"type\"
  _assert_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"annotations\"

  yq.set common .ingressNginx.controller.service.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"type\"
  _refute_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"annotations\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"type\"
  _refute_condition_and_warn .\"ingressNginx\".\"controller\".\"service\".\"annotations\"
}

# bats test_tags=conditional_set_me_letsencrypt
@test "conditional-set-me - singular conditions: letsencrypt" {

  yq.set common .issuers.letsencrypt.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"issuers\".\"letsencrypt\".\"prod\".\"email\"
  _assert_condition_and_warn .\"issuers\".\"letsencrypt\".\"staging\".\"email\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"issuers\".\"letsencrypt\".\"prod\".\"email\"
  _assert_condition_and_warn .\"issuers\".\"letsencrypt\".\"staging\".\"email\"

  yq.set common .issuers.letsencrypt.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"issuers\".\"letsencrypt\".\"prod\".\"email\"
  _refute_condition_and_warn .\"issuers\".\"letsencrypt\".\"staging\".\"email\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"issuers\".\"letsencrypt\".\"prod\".\"email\"
  _refute_condition_and_warn .\"issuers\".\"letsencrypt\".\"staging\".\"email\"
}

# bats test_tags=conditional_set_me_opsgenie_alerts
@test "conditional-set-me - singular conditions: opsgenie alerts" {

  yq.set common .alerts.opsGenieHeartbeat.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"alerts\".\"opsGenieHeartbeat\".\"name\"

  yq.set common .alerts.opsGenieHeartbeat.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"alerts\".\"opsGenieHeartbeat\".\"name\"
}

# bats test_tags=conditional_set_me_slack_alerts
@test "conditional-set-me - singular conditions: slack alerts" {

  yq.set common .alerts.alertTo \"slack\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"alerts\".\"slack\".\"channel\"

  yq.set common .alerts.alertTo \"\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"alerts\".\"slack\".\"channel\"
}

# bats test_tags=conditional_set_me_netpol_singular_sc
@test "conditional-set-me - singular conditions: network policies sc" {

  yq.set common .trivy.enabled 'true'
  yq.set common .networkPolicies.certManager.enabled 'true'
  yq.set common .networkPolicies.coredns.enabled 'true'
  yq.set sc .networkPolicies.opensearch.enabled 'true'
  yq.set sc .objectStorage.sync.secondaryUrl \"example.com\"
  yq.set sc .networkPolicies.ingressNginx.ingressOverride.enabled 'true'
  yq.set sc .networkPolicies.dex.enabled 'true'

  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"global\".\"trivy\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"certManager\".\"letsencrypt\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"coredns\".\"externalDns\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"opensearch\".\"plugins\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"secondaryUrl\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"ingressNginx\".\"ingressOverride\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"dex\".\"connectors\".\"ips\"

  yq.set common .trivy.enabled 'false'
  yq.set common .networkPolicies.certManager.enabled 'false'
  yq.set common .networkPolicies.coredns.enabled 'false'
  yq.set sc .networkPolicies.opensearch.enabled 'false'
  yq.set sc .objectStorage.sync.secondaryUrl \"\"
  yq.set sc .networkPolicies.ingressNginx.ingressOverride.enabled 'false'
  yq.set sc .networkPolicies.dex.enabled 'false'

  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"global\".\"trivy\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"certManager\".\"letsencrypt\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"coredns\".\"externalDns\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"opensearch\".\"plugins\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"secondaryUrl\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"ingressNginx\".\"ingressOverride\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"dex\".\"connectors\".\"ips\"

}

# bats test_tags=conditional_set_me_netpol_singular_wc
@test "conditional-set-me - singular conditions: network policies wc" {

  yq.set common .trivy.enabled 'true'
  yq.set common .networkPolicies.certManager.enabled 'true'
  yq.set common .networkPolicies.coredns.enabled 'true'
  yq.set wc .networkPolicies.ingressNginx.ingressOverride.enabled 'true'

  run _apply_normalise_wc
  _assert_condition_and_warn .\"networkPolicies\".\"global\".\"trivy\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"certManager\".\"letsencrypt\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"coredns\".\"externalDns\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"ingressNginx\".\"ingressOverride\".\"ips\"

  yq.set common .trivy.enabled 'false'
  yq.set common .networkPolicies.certManager.enabled 'false'
  yq.set common .networkPolicies.coredns.enabled 'false'
  yq.set wc .networkPolicies.ingressNginx.ingressOverride.enabled 'false'

  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"global\".\"trivy\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"certManager\".\"letsencrypt\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"coredns\".\"externalDns\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"ingressNginx\".\"ingressOverride\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_kured
@test "conditional-set-me - multiple conditions: network policies kured" {

  yq.set common .kured.enabled 'true'
  yq.set common .kured.notification.slack.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"

  yq.set common .kured.enabled 'true'
  yq.set common .kured.notification.slack.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"

  yq.set common .kured.enabled 'false'
  yq.set common .kured.notification.slack.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"

  yq.set common .kured.enabled 'false'
  yq.set common .kured.notification.slack.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"kured\".\"notificationSlack\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_falco
@test "conditional-set-me - multiple conditions: network policies falco" {

  yq.set common .falco.enabled 'true'
  yq.set common .networkPolicies.falco.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"

  yq.set common .falco.enabled 'true'
  yq.set common .networkPolicies.falco.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"

  yq.set common .falco.enabled 'false'
  yq.set common .networkPolicies.falco.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"

  yq.set common .falco.enabled 'false'
  yq.set common .networkPolicies.falco.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"falco\".\"plugins\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_externaldns
@test "conditional-set-me - multiple conditions: network policies externalDns" {

  yq.set common .externalDns.enabled 'true'
  yq.set common .networkPolicies.externalDns.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
  run _apply_normalise_wc
  _assert_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"

  yq.set common .externalDns.enabled 'true'
  yq.set common .networkPolicies.externalDns.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"

  yq.set common .externalDns.enabled 'false'
  yq.set common .networkPolicies.externalDns.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"

  yq.set common .externalDns.enabled 'false'
  yq.set common .networkPolicies.externalDns.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
  run _apply_normalise_wc
  _refute_condition_and_warn .\"networkPolicies\".\"externalDns\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_object_storage_swift
@test "conditional-set-me - multiple conditions: network policies swift" {

  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .thanos.objectStorage.type \"swift\"

  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"global\".\"objectStorageSwift\".\"ips\"

  yq.set sc .harbor.persistence.type \"s3\"
  yq.set sc .thanos.objectStorage.type \"swift\"

  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"global\".\"objectStorageSwift\".\"ips\"

  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .thanos.objectStorage.type \"s3\"

  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"global\".\"objectStorageSwift\".\"ips\"

  yq.set sc .harbor.persistence.type \"s3\"
  yq.set sc .thanos.objectStorage.type \"s3\"

  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"global\".\"objectStorageSwift\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_harbor
@test "conditional-set-me - multiple conditions: network policies harbor" {

  yq.set sc .harbor.enabled 'true'
  yq.set sc .networkPolicies.harbor.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"harbor\".\"registries\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"harbor\".\"jobservice\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"harbor\".\"trivy\".\"ips\"

  yq.set sc .harbor.enabled 'true'
  yq.set sc .networkPolicies.harbor.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"registries\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"jobservice\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"trivy\".\"ips\"

  yq.set sc .harbor.enabled 'false'
  yq.set sc .networkPolicies.harbor.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"registries\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"jobservice\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"trivy\".\"ips\"

  yq.set sc .harbor.enabled 'false'
  yq.set sc .networkPolicies.harbor.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"registries\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"jobservice\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"harbor\".\"trivy\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_monitoring
@test "conditional-set-me - multiple conditions: network policies monitoring" {

  yq.set sc .networkPolicies.monitoring.enabled 'true'
  yq.set sc .networkPolicies.monitoring.grafana.externalDataSources.enabled 'true'
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ips\"
  _assert_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ports\"

  yq.set sc .networkPolicies.monitoring.enabled 'true'
  yq.set sc .networkPolicies.monitoring.grafana.externalDataSources.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ports\"

  yq.set sc .networkPolicies.monitoring.enabled 'false'
  yq.set sc .networkPolicies.monitoring.grafana.externalDataSources.enabled 'true'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ports\"

  yq.set sc .networkPolicies.monitoring.enabled 'false'
  yq.set sc .networkPolicies.monitoring.grafana.externalDataSources.enabled 'false'
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ips\"
  _refute_condition_and_warn .\"networkPolicies\".\"monitoring\".\"grafana\".\"externalDataSources\".\"ports\"
}

# bats test_tags=conditional_set_me_netpol_rclone_s3
@test "conditional-set-me - multiple conditions: network policies rclone s3" {

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .objectStorage.type \"s3\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorage\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .objectStorage.type \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorage\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .objectStorage.type \"s3\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorage\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .objectStorage.type \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorage\".\"ips\"
}

# bats test_tags=conditional_set_me_netpol_rclone_swift
@test "conditional-set-me - multiple conditions: network policies rclone swift" {

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"thanos-bucket\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"thanos-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"swift\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"harbor-bucket\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"s3\"
  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"harbor-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"swift\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"s3\"
  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .objectStorage.sync.buckets "[]"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"s3\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"opensearch-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"swift\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"thanos-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"swift\"
  yq.set sc .objectStorage.sync.buckets[1].source \"harbor-bucket\"
  yq.set sc .objectStorage.sync.buckets[1].destinationType \"swift\"
  run _apply_normalise_sc
  _assert_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"s3\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"thanos-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"s3\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'true'
  yq.set sc .thanos.objectStorage.type \"s3\"
  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"harbor-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"s3\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .thanos.objectStorage.type \"s3\"
  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"harbor-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"


  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"thanos-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .objectStorage.sync.buckets "[]"
  yq.set sc .objectStorage.sync.buckets[0].source \"thanos-bucket\"
  yq.set sc .objectStorage.sync.buckets[0].destinationType \"swift\"
  yq.set sc .objectStorage.sync.buckets[1].source \"harbor-bucket\"
  yq.set sc .objectStorage.sync.buckets[1].destinationType \"swift\"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .objectStorage.sync.buckets "[]"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .thanos.objectStorage.type \"s3\"
  yq.set sc .harbor.persistence.type \"swift\"
  yq.set sc .objectStorage.sync.buckets "[]"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .thanos.objectStorage.type \"swift\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"

  yq.set sc .objectStorage.sync.enabled 'false'
  yq.set sc .thanos.objectStorage.type \"s3\"
  yq.set sc .harbor.persistence.type \"objectStorage\"
  yq.set sc .objectStorage.sync.buckets "[]"
  run _apply_normalise_sc
  _refute_condition_and_warn .\"networkPolicies\".\"rclone\".\"sync\".\"objectStorageSwift\".\"ips\"
}
