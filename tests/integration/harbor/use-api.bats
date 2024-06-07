#!/usr/bin/env bats

# bats file_tags=harbor,use-api

# Integration test: Harbor API

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"
  load_common "ctr.bash"
  load_common "harbor.bash"
  load_common "local-cluster.bash"
  load_common "yq.bash"

  local_cluster.setup dev integration.dev-ck8s.com
  local_cluster.create single-node-cache

  local_cluster.configure_selfsigned

  ck8s ops helmfile sc apply --include-transitive-needs --output simple \
    -lapp=cert-manager \
    -lapp=dex \
    -lapp=harbor \
    -lapp=ingress-nginx \
    -lapp=node-local-dns

  harbor.load_env "harbor-api"

  export harbor_endpoint
  export harbor_project
  export harbor_robot
  export harbor_robot_fullname
  export harbor_robot_id_path
  export harbor_robot_secret_path
}

setup() {
  load "../../bats.lib.bash"
  load_common "ctr.bash"
  load_common "harbor.bash"
  load_common "yq.bash"
  load_assert
}

teardown_file() {
  load "../../bats.lib.bash"
  load_common "local-cluster.bash"

  local_cluster.delete
  local_cluster.teardown
}

@test "harbor api can authenticate" {
  run harbor.get_current_user

  assert_line --regexp ".*\"username\":\"admin\".*"
  assert_success
}

@test "harbor api can create project" {
  run harbor.create_project "${harbor_project}"

  refute_output
  assert_success
}

@test "harbor api can create robot account" {
  run harbor.create_robot "${harbor_project}" "${harbor_robot}"

  assert_line --regexp ".*\"name\":\"robot.*"
  assert_success

  jq -r .id <<< "${output}" > "${harbor_robot_id_path}"
  jq -r .secret <<< "${output}" > "${harbor_robot_secret_path}"
}

@test "harbor api can authenticate with robot account" {
  run ctr.insecure login "${harbor_endpoint}" --username "${harbor_robot_fullname}" --password-stdin < "${harbor_robot_secret_path}"

  assert_line --regexp "Login Succeeded"
  assert_success
}

@test "harbor api can push image with robot account" {
  ctr pull docker.io/library/busybox
  ctr tag docker.io/library/busybox "${harbor_endpoint}/${harbor_project}/busybox:latest"
  ctr.insecure push "${harbor_endpoint}/${harbor_project}/busybox:latest"
}

@test "harbor api can pull image with robot account" {
  ctr rmi docker.io/library/busybox
  ctr rmi "${harbor_endpoint}/${harbor_project}/busybox:latest"
  ctr.insecure pull "${harbor_endpoint}/${harbor_project}/busybox:latest"
  ctr tag "${harbor_endpoint}/${harbor_project}/busybox:latest" "ctr.io/library/busybox"
  ctr rmi "${harbor_endpoint}/${harbor_project}/busybox:latest"
}

@test "harbor api can scan image with robot account" {
  run harbor.create_artefact_vulnerability_scan "${harbor_project}" "busybox" "latest"

  refute_output
  assert_success

  for each in $(seq 30); do
    echo "${each} try" >&2

    run harbor.get_artefact_vulnerabilities "${harbor_project}" "busybox" "latest"

    assert_success

    if [[ "${output}" != "{}" ]]; then
      break
    fi

    sleep 1
  done

  refute_line --regexp ".*errors.*"
}

@test "harbor api can unauthenticate with robot account" {
  ctr logout "${harbor_endpoint}"
}

@test "harbor api can delete robot account" {
  read -r harbor_robot_id < "${harbor_robot_id_path}"

  run harbor.delete_robot "${harbor_robot_id}"

  refute_output
  assert_success

  rm -f "${harbor_robot_id_path}" "${harbor_robot_secret_path}"
}

@test "harbor api can delete repository" {
  run harbor.delete_repository "${harbor_project}" "busybox"

  refute_output
  assert_success
}

@test "harbor api can delete project" {
  run harbor.delete_project "${harbor_project}"

  refute_output
  assert_success
}
