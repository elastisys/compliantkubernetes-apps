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

@test "root schemas should have titles" {
  declare -a schemas && find_schemas

  run yq4 '{ filename: .title // "" } | select(.[] == "")' "${schemas[@]}"

  refute_output
}

@test "root schemas should have descriptions" {
  declare -a schemas && find_schemas

  run yq4 '{ filename: .description // "" } | select(.[] == "")' "${schemas[@]}"

  refute_output
}

@test "root schemas should have types" {
  declare -a schemas && find_schemas

  run yq4 '{ filename: .type // "" } | select(.[] == "")' "${schemas[@]}"

  refute_output
}

@test "object schemas with properties should have titles" {
  declare -a schemas && find_schemas

  run yq4 '{
    filename: [
      .. | select(has("type") and .type == "object" and has("properties") and (
        .title == null or .title == "")
      ) | path | join "."
    ]
  } | select(.[].[] != "")' "${schemas[@]}"

  refute_output
}

@test "object schemas with properties should have descriptions" {
  declare -a schemas && find_schemas

  run yq4 '{
    filename: [
      .. | select(has("type") and .type == "object" and has("properties") and (
        .description == null or .description == "")
      ) | path | join "."
    ]
  } | select(.[].[] != "")' "${schemas[@]}"

  refute_output
}

@test "array schemas with items should have titles" {
  declare -a schemas && find_schemas

  run yq4 '{
    filename: [
      .. | select(has("type") and .type == "array" and has("items") and (
        .title == null or .title == "")
      ) | path | join "."
    ]
  } | select(.[].[] != "")' "${schemas[@]}"

  refute_output
}

@test "array schemas with items should have descriptions" {
  declare -a schemas && find_schemas

  run yq4 '{
    filename: [
      .. | select(has("type") and .type == "array" and has("items") and (
        .description == null or .description == "")
      ) | path | join "."
    ]
  } | select(.[].[] != "")' "${schemas[@]}"

  refute_output
}

# Any property should have a title
@test "properties should have types" {
  declare -a schemas && find_schemas

  # shellcheck disable=SC2016
  run yq4 '{
    filename: [
      .. | select((has("$ref") | not) and (has("type") | not) and (parent | key) == "properties" and (parent | parent | .type) == "object") | path | join "."
    ]
  } | select((.[] | length) != 0 and .[].[] != "")' "${schemas[@]}"

  refute_output
}
