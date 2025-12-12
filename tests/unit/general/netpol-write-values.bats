#!/usr/bin/env bats

# bats file_tags=static,general

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

  env.init baremetal kubespray prod --skip-object-storage

  _object_storage_cidr="$(yq '.known_cidrs | to_entries | .[] | select(.value == "*Object storage*") | .key' "${BATS_TEST_DIRNAME}/resources/known-cidrs.yaml")"
  _dns_cidr="$(yq '.known_cidrs | to_entries | .[] | select(.value == "*DNS*") | .key' "${BATS_TEST_DIRNAME}/resources/known-cidrs.yaml")"

  _sc_api_cidr="$(yq '.known_cidrs | to_entries | .[] | select(.value == "*Management Cluster API*") | .key' "${BATS_TEST_DIRNAME}/resources/known-cidrs.yaml")"
  _sc_ingress_cidr="$(yq '.known_cidrs | to_entries | .[] | select(.value == "*Management Cluster Ingress*") | .key' "${BATS_TEST_DIRNAME}/resources/known-cidrs.yaml")"
  _sc_subnet_cidr="$(yq '.known_cidrs | to_entries | .[] | select(.value == "*Management Cluster subnet*") | .key' "${BATS_TEST_DIRNAME}/resources/known-cidrs.yaml")"

  _wc_api_cidr="$(yq '.known_cidrs | to_entries | .[] | select(.value == "*Workload Cluster API*") | .key' "${BATS_TEST_DIRNAME}/resources/known-cidrs.yaml")"
  _wc_ingress_cidr="$(yq '.known_cidrs | to_entries | .[] | select(.value == "*Workload Cluster Ingress*") | .key' "${BATS_TEST_DIRNAME}/resources/known-cidrs.yaml")"
  _wc_subnet_cidr="$(yq '.known_cidrs | to_entries | .[] | select(.value == "*Workload Cluster subnet*") | .key' "${BATS_TEST_DIRNAME}/resources/known-cidrs.yaml")"

  yq.set 'common' '.global.clusterDns' "\"${_dns_cidr%/32}\""
  yq.set 'common' '.networkPolicies.global.objectStorage.ips[0]' "\"${_object_storage_cidr}\""
  yq.set 'common' '.networkPolicies.global.scIngress.ips[0]' "\"${_sc_ingress_cidr}\""
  yq.set 'common' '.networkPolicies.global.wcIngress.ips[0]' "\"${_wc_ingress_cidr}\""

  yq.set 'sc' '.networkPolicies.global.scApiserver.ips[0]' "\"${_sc_api_cidr}\""
  yq.set 'sc' '.networkPolicies.global.scNodes.ips[0]' "\"${_sc_subnet_cidr}\""

  yq.set 'wc' '.networkPolicies.global.wcApiserver.ips[0]' "\"${_wc_api_cidr}\""
  yq.set 'wc' '.networkPolicies.global.wcNodes.ips[0]' "\"${_wc_subnet_cidr}\""

}

setup() {
  load "../../bats.lib.bash"

  load_common "yq.bash"

  load_assert
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "helmfile sc netpol write-values" {
  run ck8s ops helmfile sc -l policy=netpol,netpol!=additional write-values --output-file-template "${BATS_TEST_DIRNAME}/.tmp/sc/{{ .Release.Namespace }}-{{ .Release.Name}}.yaml"
  assert_success
}

@test "helmfile wc netpol write-values" {
  run ck8s ops helmfile wc -l policy=netpol,netpol!=additional write-values --output-file-template "${BATS_TEST_DIRNAME}/.tmp/wc/{{ .Release.Namespace }}-{{ .Release.Name}}.yaml"
  assert_success
}
