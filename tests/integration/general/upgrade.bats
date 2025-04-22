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

  yq.set sc '.issuers.letsencrypt.prod.email' '"noreply@welkin.example"'
  yq.set sc '.issuers.letsencrypt.staging.email' '"noreply@welkin.example"'
  yq.set sc '.global.issuer' '"letsencrypt-staging"'
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
  ck8s ops kubectl sc delete -n kube-system configmap apps-upgrade --ignore-not-found --wait
  ck8s ops kubectl sc apply -f - <<EOF
apiVersion: v1
data:
  version: v0.41
kind: ConfigMap
metadata:
  name: apps-meta
  namespace: kube-system
EOF
}

teardown() {
  # reset

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

# COMMANDS
#
# ck8s init
# ck8s apply
# ck8s upgrade prepare
# ck8s upgrade apply
#
# ck8s init
# next:
#   ck8s apply
#   ck8s upgrade prepare
# not:
#   ck8s upgrade apply
#   ck8s init ?
#
# ck8s apply
# next:
#   ck8s apply
#   ck8s upgrade prepare
# not:
#   ck8s upgrade apply
#   ck8s init ?
#
# ck8s upgrade prepare
# next:
#   ck8s upgrade apply
# not:
#   ck8s apply
#   ck8s init ?
#
# ck8s upgrade apply
# next:
#   ck8s apply ?
#
# any other combo must throw error

@test "no upgrade apply without upgrade prepare" {
  # test 2

  gitversion.mock_static "v0.42.0"
  run ck8s version config
  assert_success
  assert_output --partial "v0.41"
  run ck8s upgrade sc "v0.42" apply
  assert_failure # because trying to apply 0.42 when config says 0.41
  assert_output --partial "invalid upgrade path"
}

@test "no ck8s apply without ck8s upgrade" {
  # test 3

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success
  assert_output --partial "locked for upgrade"

  run ck8s ops kubectl sc get -n kube-system configmap apps-upgrade -o jsonpath --template='{.data.version}'
  assert_success
  assert_output --partial "v0.42"

  # Oops, forgot to ck8s upgrade apply

  run ck8s apply sc
  assert_failure
  assert_output --partial "Migration ongoing"
}

@test "prevent apply using older config" {
  # test 4
  #
  # pretend we already upgraded
  run yq -i '.global.ck8sVersion="v0.42.0"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  ck8s ops kubectl sc apply -f - <<EOF
apiVersion: v1
data:
  version: v0.41
kind: ConfigMap
metadata:
  name: apps-meta
  namespace: kube-system
EOF

  # downgrade
  gitversion.mock_static "v0.41.0"
  run ck8s apply sc
  assert_failure
  assert_output --partial "Version mismatch. Run migration to update config."
}

@test "prevent apply using unmerged config" {
  # test 5

  gitversion.mock_static "v0.42.0"
  run ck8s version config
  assert_success
  assert_output --partial "v0.41"

  run ck8s upgrade sc "v0.42" prepare
  assert_success

  # someone changes the config
  run yq -i '.global.ck8sLastChange="something"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"

  run ck8s upgrade sc "v0.42" apply
  assert_failure
  assert_output --partial "Config timestamp mismatch"

}
