#!/usr/bin/env bats

# bats file_tags=static,general,bin:upgrade

setup_file() {
  load "../../bats.lib.bash"
  load_common "local-cluster.bash"

  export CK8S_AUTO_APPROVE="true"

  local_cluster.setup dev test.dev-ck8s.com
  local_cluster.create single-node-cache
  yq.set sc '.issuers.letsencrypt.prod.email' '"noreply@welkin.example"'
  yq.set sc '.issuers.letsencrypt.staging.email' '"noreply@welkin.example"'
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

  migration.override_path
  gitversion.setup_mocks

}

teardown_file() {
  local_cluster.delete
  local_cluster.teardown
}

@test "it works" {
  run yq -i '.global.ck8sVersion="v0.41.0"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"

  run ck8s version config
  assert_success
  assert_output --partial "v0.41"

  # TODO need a cluster running here
  #
  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" prepare
  assert_success

  gitversion.mock_static "v0.42.0"
  run ck8s upgrade sc "v0.42" apply
  assert_success

  run ck8s version config
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
# any other combo must throw error
#
# need a cluster for the apply steps, how much can be static?
# may want to have a separate migration directory for tests
#
@test "no upgrade apply without upgrade prepare" {
  run yq -i '.global.ck8sVersion="v0.41.0"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  gitversion.mock_static "v0.42.0"
  run ck8s upgrade apply
  assert_failure # because trying to apply 0.42 when config says 0.41
}

@test "no ck8s apply without ck8s upgrade" {
  run ck8s upgrade prepare
  run ck8s apply
  assert_failure
}

@test "prevent upgrade apply without upgrade prepare" {
  run yq -i '.global.ck8sVersion="v0.41.0"' "${CK8S_CONFIG_PATH}/defaults/common-config.yaml"
  gitversion.mock_static "v0.42.0"
  run ck8s upgrade apply
  assert_failure
}
#
# TODO @test "prevent apply using older config" {
# ### snapshot config
# ### upgrade
# ### revert config
# run ck8s apply
# assert_failure
# }
#
