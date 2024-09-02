#!/usr/bin/env bash

# Helpers for interacting with Harbor:
# - harbor.load_env [slug]                                                      - setup variables to have unique names for each test suite
# - harbor.setup_user_demo_image                                                - setup user demo image from the public docs repo
# - harbor.setup_project                                                        - setup project and robot for test suites
# - harbor.teardown_project                                                     - teardown project and robot for test suites
# - harbor.get [resource/path] <args...>                                        - curl with args to do get requests
# - harbor.post [resource/path] [json data] <args...>                           - curl with args to do post requests
# - harbor.delete [resource/path] <args...>                                     - curl with args to do delete requests
# - harbor.get_current_user                                                     - get current user information
# - harbor.create_project [project]                                             - create new project
# - harbor.delete_project [project]                                             - delete project, must not have repositories
# - harbor.get_robots [project]                                                 - get robots within a project
# - harbor.create_robot [project] [robot]                                       - create a robot within a project
# - harbor.delete_robot [robot-id]                                              - delete a robot by id
# - harbor.get_repositories [project]                                           - get repositories within a project
# - harbor.delete repositories [project] [repository]                           - delete a repository within a project
# - harbor.get_artefact_vulnerabilities [project] [repository] [artefact]       - get vulnerabilities for an artefact
# - harbor.create_artefact_vulnerability_scan [project] [repository] [artefact] - create a vulnerability scan for an artefact
# - harbor.create_pull_secret [cluster] [namespace]                             - create a pull secret for the robot set in the environment
# - harbor.delete_pull_secret [cluster] [namespace]                             - delete a pull secret

harbor.load_env() {
  if [[ -z "${1:-}" ]]; then
    log.fatal "usage: harbor.load_env [slug]"
  fi

  harbor_secure="$(yq.get sc '.global.verifyTls')"
  export harbor_secure

  harbor_endpoint="$(yq.get sc '.harbor.subdomain + "." + .global.baseDomain')"
  export harbor_endpoint

  harbor_username="admin"
  export harbor_username

  harbor_password="$(yq.secret ".harbor.password")"
  export harbor_password

  export harbor_project="end-to-end-${1:-"user-demo"}-project"
  export harbor_robot="end-to-end-${1:-"user-demo"}-robot"
  export harbor_robot_fullname="robot\$${harbor_project}+${harbor_robot}"
  export harbor_robot_id_path="/tmp/compliantkubernetes-apps-end-to-end-${1:-"user-demo"}-robot-id"
  export harbor_robot_secret_path="/tmp/compliantkubernetes-apps-end-to-end-${1:-"user-demo"}-robot-secret"
}

# Expects a project to be setup with harbor.setup_project
harbor.setup_user_demo_image() {
  export docs_path="${ROOT}/tests/common/docs"

  export user_demo="${docs_path}/user-demo/"
  export user_demo_image="${harbor_endpoint}/${harbor_project}/user-demo:test"

  ctr build "${user_demo}" -t "${user_demo_image}"
  if [[ "${harbor_secure}" != "true" ]]; then
    ctr.insecure push "${user_demo_image}"
  else
    ctr push "${user_demo_image}"
  fi
}

# Expects variables to be set with harbor.load_env
harbor.setup_project() {
  local output

  harbor.create_project "${harbor_project}"
  output="$(harbor.create_robot "${harbor_project}" "${harbor_robot}")"

  jq -r .id <<< "${output}" > "${harbor_robot_id_path}"
  jq -r .secret <<< "${output}" > "${harbor_robot_secret_path}"

  if [[ "${harbor_secure}" != "true" ]]; then
    ctr.insecure login --username "${harbor_robot_fullname}" --password-stdin "${harbor_endpoint}" < "${harbor_robot_secret_path}"
  else
    ctr login --username "${harbor_robot_fullname}" --password-stdin "${harbor_endpoint}" < "${harbor_robot_secret_path}"
  fi
}

# Expects variables to be set with harbor.load_env
harbor.teardown_project() {
  # Allow failure
  if [[ "${harbor_secure}" != "true" ]]; then
    ctr.insecure logout "${harbor_endpoint}" || true
  else
    ctr logout "${harbor_endpoint}" || true
  fi

  readarray -t robots < <(harbor.get_robots "${harbor_project}" | jq -r '.[].id')
  if [[ -n "${robots[*]}" ]]; then
    for robot in "${robots[@]}"; do
      harbor.delete_robot "${harbor_project}" "${robot}"
    done
  fi

  rm -f "${harbor_robot_id_path}" "${harbor_robot_secret_path}"

  readarray -t repositories < <(harbor.get_repositories "${harbor_project}" | jq -r '.[].name')
  if [[ -n "${repositories[*]}" ]]; then
    for repository in "${repositories[@]}"; do
      harbor.delete_repository "${harbor_project}" "${repository#"${harbor_project}/"}"
    done
  fi

  harbor.delete_project "${harbor_project}"
}

harbor.get() {
  if [[ "${#}" -lt 1 ]]; then
    log.fatal "usage: harbor.get [resource/path] <additional curl args...>"
  fi

  if [[ "${harbor_secure}" == "true" ]]; then
    curl -s -u "${harbor_username}:${harbor_password}" "https://${harbor_endpoint}/api/v2.0/${1}" -H "accept: application/json" "${@:2}"
  else
    curl -k -s -u "${harbor_username}:${harbor_password}" "https://${harbor_endpoint}/api/v2.0/${1}" -H "accept: application/json" "${@:2}"
  fi

}

harbor.post() {
  if [[ "${#}" -lt 1 ]]; then
    log.fatal "usage: harbor.post [resource/path] [json data] <additional curl args...>"
  fi


  if [[ "${harbor_secure}" == "true" ]]; then
    curl -s -u "${harbor_username}:${harbor_password}" "https://${harbor_endpoint}/api/v2.0/${1}" -H "accept: application/json" -H "content-type: application/json" -d "${2}" "${@:3}"
  else
    curl -k -s -u "${harbor_username}:${harbor_password}" "https://${harbor_endpoint}/api/v2.0/${1}" -H "accept: application/json" -H "content-type: application/json" -d "${2}" "${@:3}"
  fi
}

harbor.delete() {
  if [[ "${#}" -lt 1 ]]; then
    log.fatal "usage: harbor.delete [resource/path] <additional curl args...>"
  fi

  if [[ "${harbor_secure}" == "true" ]]; then
    curl -s -u "${harbor_username}:${harbor_password}" -X DELETE "https://${harbor_endpoint}/api/v2.0/${1}" -H "accept: application/json" "${@:2}"
  else
    curl -k -s -u "${harbor_username}:${harbor_password}" -X DELETE "https://${harbor_endpoint}/api/v2.0/${1}" -H "accept: application/json" "${@:2}"
  fi
}

harbor.get_current_user() {
  harbor.get users/current
}

harbor.create_project() {
  if [[ "${#}" -lt 1 ]]; then
    log.fatal "usage: harbor.create_project [project]"
  fi

  data="$(jq -cn --arg name "${1}" '
    {
      "project_name": $name
    }
  ')"

  harbor.post projects "${data}"
}

harbor.delete_project() {
  if [[ "${#}" -lt 1 ]]; then
    log.fatal "usage: harbor.delete_project [project]"
  fi

  harbor.delete "projects/${1}"
}

harbor.get_robots() {
  if [[ "${#}" -lt 1 ]]; then
    log.fatal "usage: harbor.get_robots [project]"
  fi

  harbor.get "projects/${1}/robots"
}

harbor.create_robot() {
  if [[ "${#}" -lt 2 ]]; then
    log.fatal "usage: harbor.create_robot [project] [robot]"
  fi

  data="$(jq -cn --arg namespace "${1}" --arg name "${2}" '
    {
      "name": $name,
      "level": "project",
      "duration": -1,
      "permissions": [
        {
          "access": [
            {
              "action": "pull",
              "resource": "repository"
            },
            {
              "action": "push",
              "resource": "repository"
            }
          ],
          "kind": "project",
          "namespace": $namespace
        }
      ]
    }
  ')"

  harbor.post "robots" "${data}"
}

harbor.delete_robot() {
  if [[ "${#}" -lt 1 ]]; then
    log.fatal "usage: harbor.delete_robot [robot-id]"
  fi

  harbor.delete "robots/${1}"
}

harbor.get_repositories() {
  if [[ "${#}" -lt 1 ]]; then
    log.fatal "usage: harbor.get_repositories [project]"
  fi

  harbor.get "projects/${1}/repositories"
}

harbor.delete_repository() {
  if [[ "${#}" -lt 2 ]]; then
    log.fatal "usage: harbor.delete_repository [project] [repository]"
  fi

  harbor.delete "projects/${1}/repositories/${2}"
}

harbor.get_artefact_vulnerabilities() {
  if [[ "${#}" -lt 3 ]]; then
    log.fatal "usage: harbor.get_artefact_vulnerabilities [project] [repository] [artefact]"
  fi

  harbor.get "projects/${1}/repositories/${2}/artifacts/${3}/additions/vulnerabilities" \
    -H "x-accept-vulnerabilities: application/vnd.security.vulnerability.report; version=1.1, application/vnd.scanner.adapter.vuln.report.harbor+json; version=1.0"
}

harbor.create_artefact_vulnerability_scan() {
  if [[ "${#}" -lt 3 ]]; then
    log.fatal "usage: harbor.create_artefact_vulnerability_scan [project] [repository] [artefact]"
  fi

  harbor.post "projects/${1}/repositories/${2}/artifacts/${3}/scan" ""
}

harbor.create_pull_secret() {
  if [[ "${#}" -lt 2 ]]; then
    log.fatal "usage: harbor.create_pull_secret [cluster] [namespace]"
  fi

  with_kubeconfig "${1}"
  with_namespace "${2}"

  kubectl -n "${NAMESPACE}" create secret ctr-registry pull-secret \
    "--ctr-server=${harbor_endpoint}" \
    "--ctr-username=${harbor_robot_fullname}" \
    "--ctr-password=$(<"${harbor_robot_secret_path}")"

  kubectl -n "${NAMESPACE}" patch serviceaccount default -p '{"imagePullSecrets": [{"name": "pull-secret"}]}'
}

harbor.delete_pull_secret() {
  if [[ "${#}" -lt 2 ]]; then
    log.fatal "usage: harbor.delete_pull_secret [cluster] [namespace]"
  fi

  with_kubeconfig "${1}"
  with_namespace "${2}"

  kubectl -n "${NAMESPACE}" delete secret pull-secret

  kubectl -n "${NAMESPACE}" patch serviceaccount default -p '{"imagePullSecrets": []}'
}
