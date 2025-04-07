#!/usr/bin/env bats

# Generated from tests/unit/templates/template.bats.gotmpl

# bats file_tags=template,resources,aws,capi

load "../../bats.lib.bash"

setup_file() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"
  load_assert

  gpg.setup
  env.setup

  export provider="elastx"
  export installer="capi"

  env.init "${provider}" "${installer}" prod

  env.predictable-secrets

  helmfile --log-level error -e service_cluster -f "${ROOT}/helmfile.d/" list --output json >"${BATS_FILE_TMPDIR}/releases-sc.json"
  helmfile --log-level error -e workload_cluster -f "${ROOT}/helmfile.d/" list --output json >"${BATS_FILE_TMPDIR}/releases-wc.json"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

template_test() {
  local active environment namespace name

  namespace="$(jq -r '.namespace' <<<"${2}")"
  name="$(jq -r '.name' <<<"${2}")"

  if [[ "${1}" == "sc" ]]; then
    environment="service_cluster"
  elif [[ "${1}" == "wc" ]]; then
    environment="workload_cluster"
  fi

  active="$(jq ".[] | select(.namespace == \"${namespace}\" and .name == \"${name}\") | .enabled and .installed" <"${BATS_FILE_TMPDIR}/releases-${1}.json")"

  local target="${BATS_TEST_DIRNAME}/resources/${installer}/${1}/${namespace}/${name}.yaml"

  if [[ "${active}" == "true" ]]; then
    if [[ "${CK8S_TESTS_REGENERATE_RESOURCES:-}" == "true" ]]; then
      mkdir -p "${BATS_TEST_DIRNAME}/resources/${installer}/${1}/${namespace}"
      helmfile --log-level error -e "${environment}" -f "${ROOT}/helmfile.d/" template "-lnamespace=${namespace},name=${name}" >"${target}"
    elif ! [[ -f "${target}" ]]; then
      fail "release ${1}/${namespace}/${name} is active but lacks rendered templates"
    elif ! diff -U5 "${target}" <(helmfile --log-level error -e "${environment}" -f "${ROOT}/helmfile.d/" template "-lnamespace=${namespace},name=${name}"); then
      fail "release ${1}/${namespace}/${name} has changes compared to rendered templates"
    fi
  else
    if [[ -f "${target}" ]]; then
      if [[ "${CK8S_TESTS_REGENERATE_RESOURCES:-}" == "true" ]]; then
        rm "${target}"
      else
        fail "release ${1}/${namespace}/${name} is inactive but has rendered templates"
      fi
    else
      skip "release ${1}/${namespace}/${name} is inactive"
    fi
  fi
}

# Dynamically discover releases
declare -a releases
readarray -t releases <"${BATS_TEST_DIRNAME}/../general/resources/template-list-default.json"

# Dynamically register tests
declare release
for release in "${releases[@]}"; do
  declare cluster
  for cluster in sc wc; do
    bats_test_function --description "template is consistent - elastx capi ${cluster} ${release}" --tags resources -- template_test "${cluster}" "${release}"
  done
done
