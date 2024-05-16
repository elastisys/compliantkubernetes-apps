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

# Any complex object should have a title
@test "schemas with properties should have titles" {
  declare -a schemas && find_schemas

  run yq4 '{
    filename: [
      .. | select(has("properties") and (.title == null or .title == "")) | path | join "."
    ]
  } | select(.[].[] != "")' "${schemas[@]}"

  refute_output
}

# Any complex object should have a description
@test "schemas with properties should have descriptions" {
  declare -a schemas && find_schemas

  run yq4 '{
    filename: [
      .. | select(has("properties") and (.description == null or .description == "")) | path | join "."
    ]
  } | select(.[].[] != "")' "${schemas[@]}"

  refute_output
}

# Any complex array should have a title
@test "schemas with items should have titles" {
  declare -a schemas && find_schemas

  run yq4 '{
    filename: [
      .. | select(has("items") and (.title == null or .title == "")) | path | join "."
    ]
  } | select(.[].[] != "")' "${schemas[@]}"

  refute_output
}

# Any complex array should have a description
@test "schemas with items should have descriptions" {
  declare -a schemas && find_schemas

  run yq4 '{
    filename: [
      .. | select(has("items") and (.description == null or .description == "")) | path | join "."
    ]
  } | select(.[].[] != "")' "${schemas[@]}"

  refute_output
}
