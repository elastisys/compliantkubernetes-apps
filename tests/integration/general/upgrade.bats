#!/usr/bin/env bats

# bats file_tags=static,general,bin:upgrade

setup_file() {
  load "../../bats.lib.bash"
  load_common "local-cluster.bash"
  local_cluster.configure_selfsigned

  yq.set sc '.issuers.letsencrypt.prod.email' '"noreply@welkin.example"'
  yq.set sc '.issuers.letsencrypt.staging.email' '"noreply@welkin.example"'
  yq.set sc '.global.issuer' '"letsencrypt-staging"'
  run yq -i '.global.ck8sVersion="v0.41.0"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
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
  ck8s ops kubectl sc delete -n kube-system configmap apps-version &>/dev/null || true
  ck8s ops kubectl sc create -n kube-system configmap apps-version --from-literal "version=v0.41" &>/dev/null || true
}

teardown() {
  # reset
  ck8s ops kubectl sc delete -n kube-system configmap apps-version &>/dev/null || true
  ck8s ops kubectl sc delete -n kube-system configmap apps-upgrade &>/dev/null || true

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
#
# need a cluster for the apply steps, how much can be static?
# may want to have a separate migration directory for tests
#
#
#       +----------------------+
#       |      ck8s init       |
#       +----------------------+
#         |
#         |
#         v
#       +----------------------+
#  +--- |                      |
#  |    |      ck8s apply      |
#  +--> |                      | <+
#       +----------------------+  |
#         |                       |
#         |                       |
#         v                       |
#       +----------------------+  |
#       | ck8s upgrade prepare |  |
#       +----------------------+  |
#         |                       |
#         |                       |
#         v                       |
#       +----------------------+  |
#       |  ck8s upgrade apply  | -+
#       +----------------------+

@test "no upgrade apply without upgrade prepare" {
  # test 2

  gitversion.mock_static "v0.42.0"
  run ck8s version config
  assert_success
  assert_output --partial "v0.41"
  run ck8s upgrade sc "v0.42" apply
  assert_failure # because trying to apply 0.42 when config says 0.41
  assert_output --partial "version mismatch"
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

@test "prevent apply after prepare" {
  # test 4
  # XXX Why is this the same as test 3?

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success

  run ck8s apply sc --dry-run
  assert_failure
  assert_output --partial "Migration ongoing"
}

@test "prevent apply using older config" {
  # test 5
  #
  # pretend we already upgraded
  run yq -i '.global.ck8sVersion="v0.42.0"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  ck8s ops kubectl sc delete -n kube-system configmap apps-version &>/dev/null || true
  ck8s ops kubectl sc create -n kube-system configmap apps-version --from-literal "version=v0.42" &>/dev/null || true

  gitversion.mock_static "v0.41.0"
  run ck8s apply sc --dry-run
  assert_failure
  assert_output --partial "Version mismatch. Run migration to update config."
}

# TODO how to test attempted concurrent
