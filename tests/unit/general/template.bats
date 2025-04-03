#!/usr/bin/env bats

# bats file_tags=general,template,resources

setup_file() {
  load "../../bats.lib.bash"
  load_assert

  helmfile --log-level error -f "${ROOT}/helmfile.d/" list --output json | jq -c '.[] | del(.chart, .labels, .version)' | sort >"${BATS_FILE_TMPDIR}/template-list-default.json"
}

setup() {
  load "../../bats.lib.bash"
  load_assert
}

# Note: This test populates the default template list, that other template tests relies on.
# If this is updated, then you need to update the others.
@test "template list using default environment should remain stable" {
  local target="${BATS_TEST_DIRNAME}/resources/template-list-default.json"

  if [[ "${CK8S_TESTS_REGENERATE_RESOURCES:-}" == "true" ]]; then
    echo "# regenerating resource ${target}" >&3
    mkdir -p "$(dirname "${target}")"
    helmfile --log-level error -f "${ROOT}/helmfile.d/" list --output json | jq -c '.[] | del(.chart, .enabled, .labels, .installed, .version)' | sort >"${target}"
  elif ! [[ -f "${target}" ]]; then
    fail "the template list is missing, you must regenerate resources"
  elif ! diff -U3 "${target}" <(jq -c 'del(.enabled, .installed)' "${BATS_FILE_TMPDIR}/template-list-default.json" | sort); then
    fail "the template list has changed, if the change is unintentional ensure the output is the same, else you should generate resources"
  fi
}

should_have_inactive_releases() {
  local active namespace name
  namespace="$(jq '.namespace' <<<"${1}")" name="$(jq '.name' <<<"${1}")"
  active="$(jq -r "select(.namespace == ${namespace} and .name == ${name}) | .enabled or .installed" "${BATS_FILE_TMPDIR}/template-list-default.json")"

  if [[ "${active}" == "true" ]]; then
    fail "the template list shows that ${namespace} and ${name} is active (either enabled or installed) for the default environment, they must be inactive"
  fi
}

if [[ -f "${BATS_TEST_DIRNAME}/resources/template-list-default.json" ]]; then
  declare -a releases
  readarray -t releases <"${BATS_TEST_DIRNAME}/resources/template-list-default.json"

  declare release
  for release in "${releases[@]}"; do
    bats_test_function --description "template list using default environment should have inactive releases - ${release}" -- should_have_inactive_releases "${release}"
  done
fi
