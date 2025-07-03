#!/usr/bin/env bats

# End-to-end test: Harbor use API
# Same as integration test without local-cluster setup and with verify tls.

setup_file() {
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  export CK8S_AUTO_APPROVE="true"

  load "../../bats.lib.bash"
  load_common "harbor.bash"
  load_common "yq.bash"
  load_assert

  mark.setup
  mark.punch

  export TESTS_MARKER

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
  load_common "harbor.bash"
  load_common "yq.bash"
  load_assert

  mark.check
}

teardown() {
  if [[ "${BATS_TEST_COMPLETED:-}" == 1 ]]; then
    mark.punch
  fi
}

teardown_file() {
  harbor.teardown_project

  mark.teardown
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

  jq -r .id <<<"${output}" >"${harbor_robot_id_path}"
  jq -r .secret <<<"${output}" >"${harbor_robot_secret_path}"
}

@test "harbor api can authenticate with robot account" {
  run skopeo login "${harbor_endpoint}" --username "${harbor_robot_fullname}" --password-stdin <"${harbor_robot_secret_path}"

  assert_line --regexp "Login Succeeded"
  assert_success
}

@test "harbor api can push image with robot account" {
  run skopeo sync --src docker --dest docker docker.io/library/busybox:stable "${harbor_endpoint}/${harbor_project}"
  assert_success
}

@test "harbor api can pull image with robot account" {
  local dest
  dest="$(mktemp -d)"

  run skopeo sync --src docker --dest dir "${harbor_endpoint}/${harbor_project}/busybox:stable" "${dest}"
  assert_success

  rm -r "${dest}"
}

@test "harbor api can scan image with robot account" {
  run harbor.create_artefact_vulnerability_scan "${harbor_project}" "busybox" "stable"
  refute_output
  assert_success

  for each in $(seq 30); do
    echo "${each} try" >&2

    run harbor.get_artefact_vulnerabilities "${harbor_project}" "busybox" "stable"
    assert_success

    if [[ "${output}" != "{}" ]]; then
      break
    fi

    sleep 1
  done

  refute_line --regexp ".*errors.*"
}

@test "harbor api can't pull vulnerable image with vulnerability prevention enabled" {
  local dest
  dest="$(mktemp -d)"

  harbor.update_project "${harbor_project}" '{"metadata": {"prevent_vul": "true", "severity": "high"}}'

  skopeo sync --src docker --dest docker docker.io/library/alpine:3.9 "${harbor_endpoint}/${harbor_project}"
  harbor.create_artefact_vulnerability_scan "${harbor_project}" "alpine" "3.9"

  local status
  for _ in $(seq 5); do
    status=$(harbor.get "projects/${harbor_project}/repositories/alpine/artifacts/3.9?with_scan_overview=true" |
      jq -r '.scan_overview."application/vnd.security.vulnerability.report; version=1.1".scan_status')
    if [ "$status" == "Success" ]; then
      break
    fi
    sleep 5
  done

  [ "$status" == "Success" ] || return 1

  run skopeo sync --src docker --dest dir "${harbor_endpoint}/${harbor_project}/alpine:3.9" "${dest}"

  assert_line --regexp '.*vulnerabilities.*'

  rm -r "${dest}"
}

@test "harbor api can pull vulnerable image with vulnerability prevention disabled" {
  local dest

  dest="$(mktemp -d)"

  harbor.update_project "${harbor_project}" '{"metadata": {"prevent_vul": "false"}}'

  run skopeo sync --src docker --dest dir "${harbor_endpoint}/${harbor_project}/alpine:3.9" "${dest}"

  assert_success

  harbor.delete_repository "${harbor_project}" "alpine"
  rm -r "${dest}"

}

@test "harbor api can unauthenticate with robot account" {
  run skopeo logout "${harbor_endpoint}"
  assert_success
}

@test "harbor api can delete robot account" {
  read -r harbor_robot_id <"${harbor_robot_id_path}"

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
