#!/usr/bin/env bats

# Test using Harbor via the API

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true

  load "../common/lib"
  load "../common/lib/harbor"

  common_setup

  harbor.load_env "harbor-api"

  export harbor_endpoint
  export harbor_project
  export harbor_robot
  export harbor_robot_fullname
  export harbor_robot_id_path
  export harbor_robot_secret_path
}

teardown_file() {
  harbor.teardown_project
}

setup() {
  load "../common/lib"
  load "../common/lib/harbor"

  common_setup
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
  run docker login "${harbor_endpoint}" --username "${harbor_robot_fullname}" --password-stdin < "${harbor_robot_secret_path}"

  assert_line --regexp "Login Succeeded"
  assert_success
}

@test "harbor api can push image with robot account" {
  docker pull docker.io/library/busybox
  docker tag docker.io/library/busybox "${harbor_endpoint}/${harbor_project}/busybox:latest"
  docker push "${harbor_endpoint}/${harbor_project}/busybox:latest"
}

@test "harbor api can pull image with robot account" {
  docker rmi docker.io/library/busybox
  docker rmi "${harbor_endpoint}/${harbor_project}/busybox:latest"
  docker pull "${harbor_endpoint}/${harbor_project}/busybox:latest"
  docker tag "${harbor_endpoint}/${harbor_project}/busybox:latest" "docker.io/library/busybox"
  docker rmi "${harbor_endpoint}/${harbor_project}/busybox:latest"
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
  docker logout "${harbor_endpoint}"
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
