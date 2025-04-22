#!/usr/bin/env bats

# bats file_tags=bin-diagnostics

setup() {
  load "../../bats.lib.bash"
  load_assert
  load_file

  export CK8S_AUTO_APPROVE=true
  CK8S_PGP_FP=$(yq '.creation_rules[].pgp' "${CK8S_CONFIG_PATH}/.sops.yaml")
  export CK8S_PGP_FP

  with_kubeconfig sc
}

@test "ck8s diagnostics requires CK8S_CONFIG_PATH" {
  CK8S_CONFIG_PATH="" run ck8s diagnostics sc
  assert_failure
  assert_output --partial "Missing CK8S_CONFIG_PATH"
}

@test "ck8s diagnostics creates diagnostics file" {
  echo "If this test gets stuck here for too long, visit \"http://localhost:8000\" in your browser in case you need to authenticate" >&3
  run ck8s diagnostics sc
  assert_success

  file=$(find "${CK8S_CONFIG_PATH}"/diagnostics-*.log | sort -r | head -n 1)

  assert_file_exists "${file}"
  assert_file_contains "${file}" '"sops":'

  assert_file_contains <(sops -d "${file}") "<node>"
  assert_file_contains <(sops -d "${file}") "<deployment>"
  assert_file_contains <(sops -d "${file}") "<daemonset>"
  assert_file_contains <(sops -d "${file}") "<statefulset>"
  assert_file_contains <(sops -d "${file}") "<pod>"
  assert_file_contains <(sops -d "${file}") "<top>"
  assert_file_contains <(sops -d "${file}") "<helm>"
  assert_file_contains <(sops -d "${file}") "<cert>"
  assert_file_contains <(sops -d "${file}") "<challenge>"
  assert_file_contains <(sops -d "${file}") "<event>"
}

@test "ck8s diagnostics namespaced creates diagnostics file" {
  echo "If this test gets stuck here for too long, visit \"http://localhost:8000\" in your browser in case you need to authenticate" >&3
  run ck8s diagnostics sc namespace ingress-nginx
  assert_success

  file=$(find "${CK8S_CONFIG_PATH}"/diagnostics-*.log | sort -r | head -n 1)

  assert_file_exists "${file}"
  assert_file_contains "${file}" '"sops":'

  assert_file_contains <(sops -d "${file}") "<pods>"
  assert_file_contains <(sops -d "${file}") "<top>"
  assert_file_contains <(sops -d "${file}") "<deployments>"
  assert_file_contains <(sops -d "${file}") "<daemonsets>"
  assert_file_contains <(sops -d "${file}") "<statefulsets>"
  assert_file_contains <(sops -d "${file}") "<events>"
  assert_file_contains <(sops -d "${file}") "<configmaps>"
  assert_file_contains <(sops -d "${file}") "<logs>"
}
