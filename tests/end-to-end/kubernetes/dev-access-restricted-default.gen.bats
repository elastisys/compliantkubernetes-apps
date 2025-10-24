#!/usr/bin/env bats

# Generated from tests/end-to-end/kubernetes/dev-access-restricted.bats.gotmpl

setup_file() {
  load "../../bats.lib.bash"
  with_static_wc_kubeconfig
}

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_file

  export CK8S_AUTO_APPROVE=true
  CK8S_PGP_FP=$(yq '.creation_rules[].pgp' "${CK8S_CONFIG_PATH}/.sops.yaml")
  export CK8S_PGP_FP
}

@test "static user has restricted access in namespace default" {
  local expected="${BATS_TEST_DIRNAME}/resources/dev-access-list-default"

  run kubectl auth whoami
  assert_output --partial "dev@example.com"

  run kubectl -n default auth can-i --list --no-headers
  assert_success

  if [ -n "${WELKIN_TEST_WRITEBACK+x}" ]; then
    printf '%s\n' "${lines[@]}" >"${expected}"
  fi

  assert_output "$(cat "${expected}")"
}
