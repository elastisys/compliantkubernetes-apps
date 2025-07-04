#!/usr/bin/env bats

# bats file_tags=static,general,bin:upgrade

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export CK8S_AUTO_APPROVE=true
  export CK8S_CI_SKIP_APPLY=true # quicken the apply step

  MIGRATION_ROOT="${ROOT}/tests/integration/general/migration"
  export MIGRATION_ROOT

  load "../../bats.lib.bash"
  load_common "local-cluster.bash"
  local_cluster.configure_selfsigned
}

setup() {
  load "../../bats.lib.bash"
  load_common "local-cluster.bash"
  load_common "git-version.bash"
  load_common "yq.bash"
  load_assert
  load_file
  load_mock

  env.private

  gitversion.setup_mocks

  # consistent state at start
  run yq -i '.global.ck8sVersion="v0.41.0"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  ck8s ops kubectl sc delete -n kube-system configmap welkin-apps-upgrade --ignore-not-found --wait
  ck8s ops kubectl sc apply -f - <<EOF
apiVersion: v1
data:
  version: v0.41
kind: ConfigMap
metadata:
  name: welkin-apps-meta
  namespace: kube-system
EOF
}

teardown() {
  env.teardown
}

@test "upgrading works" {
  # test 1, the happy path where everything goes well

  run ck8s version config
  assert_success
  assert_output --partial "v0.41"

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success
  assert_output --partial "locked for upgrade"

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" apply
  assert_success

  run ck8s apply sc
  assert_success

  run ck8s version sc
  assert_success
  assert_output --partial "v0.42"
}

@test "no upgrade apply without upgrade prepare" {
  # test 2

  gitversion.mock_static "v0.42.0"
  run ck8s version config
  assert_success
  assert_output --partial "v0.41"
  run ck8s upgrade sc "v0.42" apply
  assert_failure # because trying to apply 0.42 when config says 0.41
  assert_output --partial "Upgrade has not been prepared, run 'ck8s upgrade prepare' first"
}

@test "prevent apply without upgrade apply after upgrade prepare" {
  # test 3

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success
  assert_output --partial "locked for upgrade"

  run ck8s ops kubectl sc get -n kube-system configmap welkin-apps-upgrade -o jsonpath --template='{.data.version}'
  assert_success
  assert_output --partial "v0.42"

  # Oops, forgot to ck8s upgrade apply

  run ck8s apply sc
  assert_failure
  assert_output --partial "Upgrade ongoing"
}

@test "prevent a ck8s apply after ck8s upgrade prepare but prepare is not merged" {
  # test 4

  gitversion.mock_static "v0.42.0"
  run ck8s version config
  assert_success
  assert_output --partial "v0.41"

  run ck8s upgrade sc "v0.42" prepare
  assert_success

  # someone changes the config
  run yq -i '.global.ck8sConfigSerial="something"' "${CK8S_CONFIG_PATH}/sc-config.yaml"

  run ck8s upgrade sc "v0.42" apply
  assert_failure
  assert_output --partial "Config timestamp mismatch"

}

@test "prevent a ck8s apply on an old config after ck8s upgrade apply" {
  run ck8s ops kubectl sc patch -n kube-system configmap welkin-apps-meta --type=merge --patch '{"data":{"version":"v0.42"}}'

  # accidentally downgrade apps
  gitversion.mock_static "v0.41.0"
  run ck8s apply sc
  assert_failure
  assert_output --partial "Version mismatch. Run upgrade to update cluster."
}

@test "prevent prepare when migration already started" {
  run ck8s version config
  assert_success
  assert_output --partial "v0.41"

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success
  assert_output --partial "locked for upgrade"

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_failure
  assert_output --partial "Migration already in progress"
}

@test "prevent prepare on a different version" {
  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success
  assert_output --partial "locked for upgrade"

  gitversion.mock_static "v0.43.0"
  run ck8s upgrade sc "v0.43" apply
  assert_failure
  assert_output --partial "Version mismatch, upgrading to v0.43 but cluster sc was prepared for v0.42"
}
