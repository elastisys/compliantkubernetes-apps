#!/usr/bin/env bats

# bats file_tags=static,general,bin:upgrade

setup_file() {
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
  load_common "migration-override.bash"
  load_assert
  load_file
  load_mock

  env.private

  migration.override_path
  gitversion.setup_mocks

  # consistent state at start
  run yq -i '.global.ck8sVersion="v0.41.0"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  ck8s ops kubectl sc delete -n kube-system configmap apps-upgrade --wait || true
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
  # test 1, the happy path where everyhing goes well

  run ck8s version config
  assert_success
  assert_output --partial "v0.41"

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" apply
  assert_success

  run ck8s apply sc --dry-run
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
  assert_output --partial "Apps version mismatch"
}

@test "no ck8s apply without ck8s upgrade" {
  # test 3

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success

  # Oops, forgot to ck8s upgrade apply

  run ck8s apply sc --dry-run
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
  run ck8s apply sc --dry-run
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
