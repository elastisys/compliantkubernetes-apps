#!/usr/bin/env bats

# bats file_tags=static,general

setup() {
  load "../common/lib"

  export CK8S_CONFIG_PATH="/dev/null"

  common_setup
}

find_schemas() {
  readarray -t schemas <<< "$(find "${ROOT}/config/schemas/" -type f -name '*.yaml')"
}

@test "schema should have titles for root schemas" {
  declare -a schemas && find_schemas
  for schema in "${schemas[@]}"; do
    echo "# ${schema}" >&2
    run yq4 '.title // ""' "${schema}"
    assert_output
  done
}

@test "schema should have descriptions for root schemas" {
  declare -a schemas && find_schemas
  for schema in "${schemas[@]}"; do
    echo "# ${schema}" >&2
    run yq4 '.description // ""' "${schema}"
    assert_output
  done
}
