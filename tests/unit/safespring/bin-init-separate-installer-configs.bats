#!/usr/bin/env bats

# bats file_tags=static,bin:init,safespring

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"

  gpg.setup
  env.setup

}

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "yq.bash"

  load_assert
  load_file
  load "../templates/bin-init.bash"

  env.private
}

teardown() {
  env.teardown
}

teardown_file() {
  env.teardown
  gpg.teardown
}

@test "config is different - safespring:capi:prod" {
  env.init safespring capi prod
  test_init_successful

  assert_equal "$(yq.get sc '.networkPolicies.global.ingressMode')" "InternalProxy"
  assert_equal "$(yq.get sc '.ingressNginx.controller.service.enabled')" "true"
  assert_equal "$(yq.get sc '.ingressNginx.controller.service.type')" "LoadBalancer"
  assert_equal "$(yq.get sc '.ingressNginx.controller.useHostPort')" "false"
  assert_equal "$(yq.get wc '.networkPolicies.global.ingressMode')" "InternalProxy"
  assert_equal "$(yq.get wc '.ingressNginx.controller.service.enabled')" "true"
  assert_equal "$(yq.get wc '.ingressNginx.controller.service.type')" "LoadBalancer"
  assert_equal "$(yq.get wc '.ingressNginx.controller.useHostPort')" "false"
}

@test "config is different - safespring:kubespray:prod" {
  env.init safespring kubespray prod
  test_init_successful

  assert_equal "$(yq.get sc '.networkPolicies.global.ingressMode')" "DirectRouting"
  assert_equal "$(yq.get sc '.ingressNginx.controller.service.enabled')" "false"
  assert_equal "$(yq.get sc '.ingressNginx.controller.service.type')" "NodePort"
  assert_equal "$(yq.get sc '.ingressNginx.controller.useHostPort')" "true"
  assert_equal "$(yq.get wc '.networkPolicies.global.ingressMode')" "DirectRouting"
  assert_equal "$(yq.get wc '.ingressNginx.controller.service.enabled')" "false"
  assert_equal "$(yq.get wc '.ingressNginx.controller.service.type')" "NodePort"
  assert_equal "$(yq.get wc '.ingressNginx.controller.useHostPort')" "true"
}
